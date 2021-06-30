function [data_byte,sim_options] = ieee802_11a_rx_func(rx_signal_40,upsample)
sim_consts = set_sim_consts;
cyc=0;err_cyc=0;
viterbi='soft';
%% srrc
flt1=rcosine(1,upsample,'fir/sqrt',1,64);
%rx_signal_40=rcosflt(rx_signal_40,1,1, 'filter', flt1);
rx_signal(:,1)=rx_signal_40(1:upsample:end);
while (1)
tic;
%% plot pwelch
%figure(10);
clf;
subplot(241);
plot(real(rx_signal(1:end/8)));hold on;plot(imag(rx_signal(1:end/8)));
title('ԭʼ�ź�ʱ����');
subplot(242);
%figure(11);
if size(rx_signal,1)>8
    pwelch(rx_signal,[],[],[],20e6,'centered','psd');
    title('ԭʼ�źŹ������ܶ�');
else
    break;
end
%% packet search
[dc_offset,thres_idx] = rx_search_packet_short3(rx_signal);
disp(['thres_idx_short=',num2str(thres_idx)]);
if thres_idx>=length(rx_signal)-32
    break;
end
rx_signal_coarse_sync = rx_signal(thres_idx:end)-dc_offset;
subplot(243);
if size(rx_signal_coarse_sync,1)>400
    plot(abs(rx_signal_coarse_sync(1:220)));
    title('��ͬ���������');
else
    break;
end
if thres_idx>60
    snr_est=20*log10(mean(abs(rx_signal(thres_idx+100:thres_idx+131)))) ...
        -20*log10(mean(abs(rx_signal(thres_idx-60:thres_idx-30))));
else
    snr_est=20*log10(mean(abs(rx_signal(thres_idx+thres_idx/2+1:thres_idx+thres_idx)))) ...
        -20*log10(mean(abs(rx_signal(thres_idx-thres_idx+1:thres_idx-thres_idx/2))));
end
rx_signal_coarse=rx_signal_coarse_sync;
freq_est_short=0;
%% Fine time synchronization
end_search=500;
thres_idx_fine = rx_search_packet_long(end_search,rx_signal_coarse);
if thres_idx_fine~=end_search
    rx_signal_fine_sync = rx_signal_coarse(thres_idx_fine+32:end);
else
    rx_signal=rx_signal_coarse(end_search:end);
    disp('short sync error');
    continue;
end
subplot(244);
if length(rx_signal_fine_sync)>320
    plot(abs(rx_signal_fine_sync(1:320)));
else
    plot(abs(rx_signal_fine_sync));
end
title('��ͬ���ź�ʱ����');
disp(['sync_index=',num2str(thres_idx),'+',num2str(thres_idx_fine),'=',num2str(thres_idx+thres_idx_fine)]);
%% Frequency error estimation and correction
[rx_signal_fine, freq_est] = rx_frequency_sync_long(rx_signal_fine_sync);
%% Return to frequency domain
[freq_tr_syms,  freq_data] = rx_timed_to_freqd(rx_signal_fine);
%% Channel estimation
channel_est = rx_estimate_channel(freq_tr_syms);
subplot(245);
plot([zeros(6,1);20*log10(abs(channel_est(1:26)));0;20*log10(abs(channel_est(27:52)));zeros(5,1)]);hold on;
title('�ŵ�����ͼ');
channel_est_data=repmat(channel_est,1,size(freq_data,2));
chan_data=freq_data.*conj(channel_est_data);
chan_data_amp=abs(channel_est_data(sim_consts.DataSubcPatt,:)).^2;
chan_data_syms=chan_data(sim_consts.DataSubcPatt,:);
chan_pilot_syms=chan_data(sim_consts.PilotSubcPatt,:);
%% Phase tracker, returns phase error corrected symbols
[correction_phases,phase_error] = rx_pilot_phase_est(chan_data_syms,chan_pilot_syms);
%freq_data_syms = chan_data_syms.*exp(-1i.*correction_phases(sim_consts.DataSubcPatt,:));
freq_data_syms = chan_data_syms;
%% signal
%get the signal part
freq_signal_syms=freq_data_syms(:,1);
% Demodulate
% Deinterleave 
[soft_bits,evm_signal] = rx_bpsk_demod_dynamic_soft(freq_signal_syms,chan_data_amp(:,1));
soft_bits=soft_bits(:)';
signal_deint_bits = rx_deinterleave(soft_bits,'BPSK');
% depuncture
[signal_depunc_bits,signal_erase] = rx_depuncture(signal_deint_bits,'R1/2');
% Vitervi decoding
t = poly2trellis(7, [133, 171]);
signal_bits = vitdec( signal_depunc_bits, t, 24, 'term', 'soft',3, ...
    [],signal_erase);
signal_bits=signal_bits(1:24);
%get RATE and LENGTH from signal_bits
[data_rate,data_length,signal_error]=rate_length(signal_bits);
if signal_error==1
    err_cyc=err_cyc+1;
    index_next=thres_idx+thres_idx_fine+1000;
    rx_signal=rx_signal(index_next:end);
    continue;
end
%get data parameters
sim_options=rx_get_data_parameter(data_rate,data_length);
%% calculate ofdm symbols
ofdm_symbol_num=ceil((16+sim_options.PacketLength.*8+6)/(sim_options.rate*4));
if ofdm_symbol_num+1>size(correction_phases,2)
    break;
end
subplot(246);
plot(phase_error(1,1:ofdm_symbol_num+1));
title('��λУ������');
%% data
subplot(247);
plot(real(freq_signal_syms)./chan_data_amp(:,1),imag(freq_signal_syms)./chan_data_amp(:,1),'*r');
hold on;
freq_data_syms_ser=reshape(freq_data_syms(:,2:ofdm_symbol_num+1),48*ofdm_symbol_num,1);
chan_data_amp_ser=reshape(chan_data_amp(:,2:ofdm_symbol_num+1),48*ofdm_symbol_num,1);
plot(real(freq_data_syms_ser)./chan_data_amp_ser,imag(freq_data_syms_ser)./chan_data_amp_ser,'.');
axis([-1.5,1.5,-1.5,1.5]);
title('��λ����������ͼ');
% Demodulate
[data_soft_bits,evm_data]=rx_demodulate_dynamic_soft ...
    (freq_data_syms_ser,chan_data_amp_ser,sim_options.Modulation);
% Deinterleave 
data_deint_bits = rx_deinterleave(data_soft_bits,sim_options.Modulation);
% depuncture
[data_depunc_bits,data_erase] = rx_depuncture(data_deint_bits,sim_options.ConvCodeRate);
% Viterbi decoding
if ~isempty(findstr(viterbi, 'soft'))
    data_descramble_bits = vitdec( data_depunc_bits(1:(16+sim_options.PacketLength*8+6)*2), t, 96, 'term', 'soft',3, ...
        [],data_erase(1:(16+sim_options.PacketLength*8+6)*2));
else
    data_depunc_bits=data_depunc_bits>=4;
    data_descramble_bits = vitdec( data_depunc_bits, t, 48, 'term', 'hard', ...
        [],data_erase);
end
%desramble
[scramble,data_bits]=rx_descramble(data_descramble_bits);
%remove pad
service_bits=data_bits(1:16);
inf_bits=data_bits(16+1:16+sim_options.PacketLength*8);
bits=inf_bits(1:length(inf_bits)-32);
bits_r=reshape(bits,8,length(bits)/8).';
data_byte=bi2de(bits_r,'left-msb');
%use crc to detect the "receiving" inf_bits
ret=crc32(inf_bits(1:length(inf_bits)-32)).';
crc_bits=inf_bits(length(inf_bits)-31:length(inf_bits));
crc_outputs=sum(xor(ret,crc_bits),2);
if crc_outputs==0
    crc_ok='YES';
    cyc=cyc+1;
    evm(cyc)=evm_data;
    freq_khz(cyc)=(freq_est+freq_est_short)/1e3;
else
    crc_ok='NO';
    err_cyc=err_cyc+1;
end
disp(['crc32=',crc_ok]);
[uV sV] = memory;
time=toc;
mem=round(uV.MemUsedMATLAB/2^20);
subplot(248);
axis off;
text(0.1,0.9,['��ͬ�����',num2str(thres_idx),';��ͬ�����',num2str(thres_idx_fine)]);
text(0.1,0.8,['Ƶƫ����ֵ',num2str((freq_est+freq_est_short)/1e3,3),'KHz']);
text(0.1,0.7,['������',num2str(scramble)]);
text(0.1,0.6,['service',num2str(service_bits)]);
text(0.1,0.5,['������',num2str(sim_options.rate),'Mbps,','����ģʽ',sim_options.Modulation]);
text(0.1,0.4,['���ݳ��� ',num2str(sim_options.PacketLength),'byte ,',num2str(ofdm_symbol_num),'ofdms']);
text(0.1,0.3,['data�����Ϣ,crc�Ƿ�ͨ��:',crc_ok]);
text(0.1,0.2,['signal����ͼEVM:',num2str(evm_signal*100,2),'%,',num2str(20*log10(evm_signal),3),'dB']);
text(0.1,0.1,['data����ͼEVM:',num2str(evm_data*100,2),'%,',num2str(20*log10(evm_data),3),'dB']);
text(0.1,0.0,['�����S/N����ֵ:',num2str(snr_est,4),'dB']);
title(['crc ok=',num2str(cyc),';crc err=',num2str(err_cyc),';mem=',num2str(mem),'MB',';FPS=',num2str(1/time)]);
%% calculate next frame
index_next=thres_idx+thres_idx_fine+160+80*(ofdm_symbol_num+1);
if length(rx_signal)-index_next>1000
    rx_signal=rx_signal(index_next:end);
else
    break;
end 
pause(0.2);
break;
end
disp(['��ȷ֡��',num2str(cyc),' frame']);
disp(['����֡��',num2str(err_cyc),' frame']);