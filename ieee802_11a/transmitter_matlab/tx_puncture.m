% 打孔,每六个中删除两个数据
function punctured_bits = tx_puncture(in_bits, code_rate)
punc_patt=[1 2 3 6];
punc_patt_size = 6;
puncture_table = reshape(in_bits,punc_patt_size,length(in_bits)/punc_patt_size);
tx_table = puncture_table(punc_patt,:);
punctured_bits = [tx_table(:)'];

