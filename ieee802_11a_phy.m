clearvars -except times;close all;warning off;

addpath ieee802_11a\transmitter_matlab
addpath ieee802_11a\receiver_matlab
in_byte=repmat([1:100],1,10);
rate=54;
upsample=2; 
tx_11a=ieee802_11a_tx_func(in_byte,54,upsample);
txdata=repmat([zeros(size(tx_11a));tx_11a],2,1);
%Rx=[txdata;txdata;txdata;txdata;txdata;txdata];
Rx = txdata;                                   

upsample=2;
[data_byte_recv,sim_options] = ieee802_11a_rx_func(Rx(:,1),upsample);