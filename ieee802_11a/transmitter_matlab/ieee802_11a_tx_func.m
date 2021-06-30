function tx_11a = ieee802_11a_tx_func(in_byte,rate,upsample)
sim_consts = set_sim_consts_tx;
sim_options.PacketLength=length(in_byte)+4;
sim_options.rate=rate;
sim_options.upsample=upsample;
sim_options.ConvCodeRate='R3/4';
sim_options.Modulation='64QAM';

%% 数据生成
in_byte_col(:,1)=in_byte;
in_bits_1=de2bi(in_byte_col,8); %转换成比特数据
in_bits_r=in_bits_1(:,8:-1:1);
in_bits_re=in_bits_r.';
in_bits_s=in_bits_re(:);
in_bits(1,:)=in_bits_s;
ret=crc32(in_bits); %计算crc校验值
inf_bits=[in_bits ret.']; %得到完整的数据
service=zeros(1,16);
%数据成帧 添加16bit业务位以及6bit的尾比特，和填充比特用于保证帧结构
data_bits=tx_generate_data(inf_bits,service,sim_options); 
%% 添加扰码
scramble_int=[1,1,1,1,0,0,0];
scramble_bits=scramble_lc(scramble_int,data_bits,sim_options);
%% 2 1 7卷积编码，使用802.11固定的卷积编码方案
coded_bit_stream = tx_conv_encoder(scramble_bits); 
%% 打孔 每六个中删除两个数据
tx_bits = tx_puncture(coded_bit_stream, sim_options.ConvCodeRate);
rdy_to_mod_bits =tx_bits;
%% 交织
rdy_to_mod_bits = tx_interleaver(rdy_to_mod_bits,sim_options.Modulation);
%% 调制
mod_syms = tx_modulate(rdy_to_mod_bits, sim_options.Modulation);
%% 插入导频
mod_ofdm_syms = tx_add_pilot_syms(mod_syms);
%% ifft
time_syms = tx_freqd_to_timed(mod_ofdm_syms,sim_options.upsample);
%% 添加保护间隔
time_signal = tx_add_cyclic_prefix(time_syms,sim_options.upsample);
%% 添加训练符号
preamble = tx_gen_preamble(sim_options);
%% 生成帧头信号
l_sig=tx_gen_sig(sim_options);
%% 数据成帧
tx_11a=[preamble l_sig time_signal].';
%% psd
pwelch(tx_11a,[],[],[],20e6*sim_options.upsample,'centered','psd');
%% fir
% flt1=rcosine(1,sim_options.upsample,'fir/sqrt',0.01,64);
% flt1=[38,18,-77,-102,39,67,-104,-93,152,81,-229,-56,317,-10,-414,120, ...
% 507,-291,-578,531,608,-856,-566,1285,414,-1867,-77,2727,-669,-4411,3364,16403, ...
% 16403,3364,-4411,-669,2727,-77,-1867,414,1285,-566,-856,608,531,-578,-291,507, ...
% 120,-414,-10,317,-56,-229,81,152,-93,-104,67,39,-102,-77,18,38];
% tx_11a=rcosflt(tx_11a,1,1, 'filter', flt1).';