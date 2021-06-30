% 交织

function interleaved_bits = tx_interleaver(in_bits, Modulation)
global sim_consts;
interleaver_depth = sim_consts.NumDataSubc * get_bits_per_symbol(Modulation);
num_symbols = length(in_bits)/interleaver_depth;

% 得到交织参数
single_intlvr_patt = tx_gen_intlvr_patt(interleaver_depth);
% 生成交织匹配器
intlvr_patt = interleaver_depth*ones(interleaver_depth, num_symbols);
intlvr_patt = intlvr_patt*diag(0:num_symbols-1);
intlvr_patt = intlvr_patt+repmat(single_intlvr_patt', 1, num_symbols);
intlvr_patt = intlvr_patt(:);

% 形成交织
interleaved_bits(intlvr_patt) = in_bits;
