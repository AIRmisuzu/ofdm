function [dc_offset,thres_idx] = rx_search_packet_short3(rx_signal)
global sim_consts;
%% load local short training
Nrx=size(rx_signal,2);
Ns=size(rx_signal,1);
L=16;
thres_idx=Ns-L*2;
pass=0;
for i=1:Ns-L*2
%     rx_mean(1,i)=mean((rx_signal(i:i+L-1)));
%     rx_mean(i)=0;
    for j=0:15
        rx_mean(j+1,i)=mean((rx_signal(i+j:i+j+L-1)));
    end
    rx_signal_nodc1=rx_signal(i:i+L-1)-rx_mean(:,i);
    rx_signal_dc=rx_signal(i:i+L-1);
    rx_signal_nodc1_norm=(real(rx_signal_nodc1)>0)*2-1+1i*((imag(rx_signal_nodc1)>0)*2-1);
    rx_signal_nodc2=rx_signal(i+L:i+L*2-1)-rx_mean(:,i);
    rx_delay_corr = abs(sum(rx_signal_nodc1.*conj(rx_signal_nodc2)));
    rx_self_corr  = sum(rx_signal_nodc2.*conj(rx_signal_nodc2));
    rx_corr(i)=rx_delay_corr./rx_self_corr;
    pass_cnt(i)=pass;
    if rx_corr(i)>=0.75*Nrx
        if pass~=15
            pass=pass+1;
        elseif pass==15
            thres_idx = i - 15; break
        else
            pass=0;
        end
    else
        pass=0;
    end
end
dc_offset=rx_mean(1,thres_idx);
% dc_offset=rx_mean(1,i);
% dc_offset=0;
figure(5);clf;
set(gcf,'name','??ͬ??');
subplot(311);plot(rx_corr);
subplot(312);plot(rx_delay_corr);
subplot(313);plot(pass_cnt);
figure(1);