clearvars -except times;close all;warning off;

addpath ieee802_11a\transmitter_matlab
addpath ieee802_11a\receiver_matlab
addpath ieee802_11a\common_matlab
in_byte=repmat([1:100],1,10);
rate=54;
upsample=2; 
% 发送端
tx_11a=ieee802_11a_tx_func(in_byte,54,upsample);

% 信道
t=0:1:length(tx_11a)-1;
lo_data1=exp(1j*2*pi*t*0.001)';
lo_data2=exp(1j*2*pi*t*0.001)';
%tx_11a=tx_11a.*lo_data1.*0.01+tx_11a.*lo_data2.*0.01+tx_11a.*0.98;
tx_11a = tx_11a.*lo_data1;
txdata=repmat([zeros(size(tx_11a));tx_11a],2,1);
%Rx=[txdata;txdata;txdata;txdata;txdata;txdata];
Rx = tx_11a;                                   
% 接收端
upsample=2;
[data_byte_recv,sim_options] = ieee802_11a_rx_func(Rx(:,1),upsample);