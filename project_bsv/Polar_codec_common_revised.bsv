package Polar_codec_common_revised;

typedef 256 Codeword_len;
typedef 64 MAX_N_SUBCODEWORD; 

import Vector::*;

Integer codeword_len = 256;

typedef Bit#(Codeword_len) Codeword;

typedef struct {bit is_finite; Int#(n) val;} LLR#(numeric type n) deriving(Bits, Eq);  
typedef Vector#(Codeword_len, LLR#(n)) LLR_vector#(numeric type n);

typedef Bit#(64) ENCODED;
typedef UInt#(6) MSG_IND_IDX;
typedef UInt#(3) PAGE_NUM;

typedef 256 MSG_BIT_WIDTH;
typedef 8 LOG_MSG_BIT_WIDTH;
typedef 9 LOG_MSG_BIT_WIDTH_PLUS_1;
typedef Bit#(MSG_BIT_WIDTH) MESSAGE;
typedef UInt#(LOG_MSG_BIT_WIDTH_PLUS_1) MSG_CNT;
typedef struct {MESSAGE msg_vec; MSG_CNT msg_cnt;} MSG_MSG_CNT deriving(Bits, Eq);
typedef struct {MESSAGE msg_vec; MSG_CNT msg_cnt; MSG_IND_IDX msg_ind_idx; PAGE_NUM page_num;} TAKE_PARTIAL_OUT deriving(Bits, Eq);


typedef Vector#(4, LLR#(n)) LLR_N4#(numeric type n);
typedef Vector#(8, LLR#(n)) LLR_N8#(numeric type n);
typedef Vector#(16, LLR#(n)) LLR_N16#(numeric type n);
typedef Vector#(32, LLR#(n)) LLR_N32#(numeric type n);
typedef Vector#(64, LLR#(n)) LLR_N64#(numeric type n);
typedef Vector#(128, LLR#(n)) LLR_N128#(numeric type n);

//typedef enum {R1N256, R1N128, R1N64, R1N32, R1N16, R1N8, R1N4, R0N256, R0N128, R0N64, R0N32, R0N16, R0N8, REPN16, REPN8, ML2N16, ML2N8, ML3N8, SPCN16, SPCN8, REPSPCN8, FCN4} Instruction deriving(Bits, Eq);
typedef enum {R1N256, R1N128, R1N64, R1N32, R1N16, R1N8, R1N4, R0N256, R0N128, R0N64, R0N32, R0N16, R0N8, REPN16, REPN8, ML2N16, ML2N8, ML3N8, SPCN16, SPCN8, REPSPCN8, R14SPCN8, ML2R04N8, REPR04N8, FCN4} Instruction deriving(Bits, Eq);



typedef struct {Bit#(6) offset; Vector#(64, Instruction) instructionVector;} SubcodeInstruction deriving(Bits, Eq);
		
`include "encoder_config.bsv"

function LLR#(m) llrUpdatef(LLR#(n) a, LLR#(n) b) provisos(Add#(n,1,m));
	LLR#(m) f_a_b;
	f_a_b.is_finite = 0;
	f_a_b.val = 0;
	Int#(m) max_abs_llr_val = ~(1 << (valueOf(m)-1));
	case({a.is_finite, b.is_finite}) matches
		2'b11: 	begin
        			Int#(m) min_abs_a_b = signExtend(min(abs(a.val), abs(b.val)));
				f_a_b.is_finite = 1;
        			f_a_b.val = (signum(a.val) == signum(b.val)) ? min_abs_a_b : -min_abs_a_b;
			end
		2'b10:	begin
				f_a_b.is_finite = 1;
				f_a_b.val = signExtend(b.val > 0 ? a.val : -a.val);
			end
		2'b01: 	begin
                                f_a_b.is_finite = 1;
                                f_a_b.val = signExtend(a.val > 0 ? b.val : -b.val);					
			end
		2'b00:  begin
				f_a_b.is_finite = 0;
				f_a_b.val = signum(a.val)==signum(b.val) ? max_abs_llr_val : -max_abs_llr_val;
			end
		
	endcase
        return f_a_b;
endfunction: llrUpdatef

function LLR#(m) llrUpdateg(LLR#(n) a, LLR#(n) b, bit s) provisos(Add#(n,1,m));
	LLR#(m) g_a_b;
	g_a_b.is_finite = 0;
	g_a_b.val = 0;
        Int#(m) max_abs_llr_val = ~(1 << (valueOf(m)-1));
        case({a.is_finite, b.is_finite}) matches
                2'b11:  begin
                        	g_a_b.is_finite = 1;
                                g_a_b.val = (s==0) ? signExtend(a.val) + signExtend(b.val) : signExtend(-a.val) +signExtend(b.val);
                	end
                2'b10: 	begin
                                g_a_b.is_finite = 0;
                                //g_a_b.val = signExtend(signum(b.val));
				g_a_b.val = b.val > 0 ? max_abs_llr_val : -max_abs_llr_val; 
                       	end
                2'b01: 	begin
                                g_a_b.is_finite = 0;
                                //g_a_b.val = signExtend((s==0) ? signum(a.val) : -signum(a.val));
				g_a_b.val = (((s == 0) && (a.val > 0)) || ((s == 1) && (a.val < 0))) ? max_abs_llr_val : -max_abs_llr_val; 
                        end
                2'b00: 	begin
				if ((s == 0 && (signum(a.val) == signum(b.val))) || (s == 1 && (signum(a.val) != signum(b.val))))  begin
					g_a_b.is_finite = 0;
					g_a_b.val = b.val > 0 ? max_abs_llr_val : -max_abs_llr_val; //signExtend(signum(b.val));		
				end
				else begin
					g_a_b.is_finite = 1;
					g_a_b.val = 0;
				end	
                        end
        endcase
        return g_a_b;
endfunction: llrUpdateg

function LLR#(3) initLLRUpdatef(bit a, bit b);
	LLR#(3) f_a_b;
	f_a_b.val = 	case({a,b}) 
				2'b00: 1;
				2'b01: -1;
				2'b10: -1;
				2'b11: 3;
			endcase;
	f_a_b.is_finite = case({a,b})
                                2'b00: 1;
                                2'b01: 1;
                                2'b10: 1;
                                2'b11: 0;
                        endcase;
	return f_a_b;
endfunction: initLLRUpdatef

function LLR#(3) initLLRUpdateg(bit a, bit b, bit s);
	LLR#(3) g_a_b;
	g_a_b.val =	case({a,b,s})
				3'b000: 2;
                                3'b010: -3;
                                3'b100: -3;
                                3'b110: -3;
                                3'b001: 0;
                	        3'b011: -3;
                        	3'b101: 3;
                                3'b111: 0;
			endcase;
        g_a_b.is_finite = case({a,b,s})
                                3'b000: 1;
                                3'b010: 0;
                                3'b100: 0;
                                3'b110: 0;
                                3'b001: 1;
                                3'b011: 0;
                                3'b101: 0;
                                3'b111: 1;
                        endcase;
	return g_a_b;
endfunction: initLLRUpdateg

function LLR#(m) llrUpdateN2(LLR#(n) a, LLR#(n) b, bit s, bit c) provisos(Add#(n,1,m));
	return (c == 0) ? llrUpdatef(a,b) : llrUpdateg(a,b,s);
endfunction: llrUpdateN2

function LLR#(3) initLLRUpdateN2(bit a, bit b, bit s, bit c);
        return (c == 0) ? initLLRUpdatef(a,b) : initLLRUpdateg(a,b,s);
endfunction: initLLRUpdateN2

function bit hardDecision(LLR#(n) llr);
	return llr.val >= 0 ? 0 : 1;
endfunction: hardDecision

//(* noinline *)
function Bit#(4) polarEncoderN4(Vector#(4, LLR#(n)) llr_in, Bit#(4) msg_ind, Bit#(4) msg_bits);
	Bit#(4) u_hat = 0;
	let llr1_1 = llrUpdatef(llr_in[0], llr_in[2]);
	let llr1_2 = llrUpdatef(llr_in[1], llr_in[3]);
	let llr2_1 = llrUpdatef(llr1_1, llr1_2);
	u_hat[0] = (msg_ind[0] == 1) ? msg_bits[0] : hardDecision(llr2_1);

        let llr2_2 = llrUpdateg(llr1_1, llr1_2, u_hat[0]);
        u_hat[1] = (msg_ind[1] == 1) ? msg_bits[1] : hardDecision(llr2_2);

        let llr1_3 = llrUpdateg(llr_in[0], llr_in[2], u_hat[0] ^ u_hat[1]);          
        let llr1_4 = llrUpdateg(llr_in[1], llr_in[3], u_hat[1]);
	let llr2_3 = llrUpdatef(llr1_3, llr1_4);
	u_hat[2] = (msg_ind[2] == 1) ? msg_bits[2] : hardDecision(llr2_3);

        let llr2_4 = llrUpdateg(llr1_3, llr1_4, u_hat[2]);
        u_hat[3] = (msg_ind[3] == 1) ? msg_bits[3] : hardDecision(llr2_4);
	return u_hat;
endfunction: polarEncoderN4

function Bit#(2) mulG2(Bit#(2) u);
        Bit#(2) encoded;
        encoded[0] = u[0] ^ u[1];
        encoded[1] = u[1];
        return encoded;
endfunction

function Bit#(4) mulG4(Bit#(4) u);
	Bit#(4) encoded;
	encoded[0] = u[0] ^ u[1] ^ u[2] ^ u[3];
	encoded[1] = u[1] ^ u[3];
	encoded[2] = u[2] ^ u[3];
	encoded[3] = u[3];
	return encoded;
endfunction

function Bit#(8) mulG8(Bit#(8) u);
	Bit#(8) encoded;
	encoded[0] = u[0] ^ u[1] ^ u[2] ^ u[3] ^ u[4] ^ u[5] ^ u[6] ^ u[7];
	encoded[1] = u[1] ^ u[3] ^ u[5] ^ u[7];
	encoded[2] = u[2] ^ u[3] ^ u[6] ^ u[7];
	encoded[3] = u[3] ^ u[7];
        encoded[4] = u[4] ^ u[5] ^ u[6] ^ u[7];
        encoded[5] = u[5] ^ u[7];
        encoded[6] = u[6] ^ u[7];
        encoded[7] = u[7];
	return encoded;
endfunction


function Bit#(16) mulG16(Bit#(16) u);
        Bit#(16) encoded;
        encoded[0] = u[0] ^ u[1] ^ u[2] ^ u[3] ^ u[4] ^ u[5] ^ u[6] ^ u[7] ^ u[8] ^ u[9] ^ u[10] ^ u[11] ^ u[12] ^ u[13] ^ u[14] ^ u[15];
        encoded[1] = u[1] ^ u[3] ^ u[5] ^ u[7] ^ u[9] ^ u[11] ^ u[13] ^ u[15];
        encoded[2] = u[2] ^ u[3] ^ u[6] ^ u[7] ^ u[10] ^ u[11] ^ u[14] ^ u[15];
        encoded[3] = u[3] ^ u[7] ^ u[11] ^ u[15];
        encoded[4] = u[4] ^ u[5] ^ u[6] ^ u[7] ^ u[12] ^ u[13] ^ u[14] ^ u[15];
        encoded[5] = u[5] ^ u[7] ^ u[13] ^ u[15];
        encoded[6]  = u[6] ^ u[7] ^ u[14] ^ u[15];
        encoded[7]  = u[7] ^ u[15];
        encoded[8] =  u[8] ^ u[9] ^ u[10] ^ u[11] ^ u[12] ^ u[13] ^ u[14] ^ u[15];
        encoded[9] =  u[9] ^ u[11] ^ u[13] ^ u[15];
        encoded[10] = u[10] ^ u[11] ^ u[14] ^ u[15];
        encoded[11] = u[11] ^ u[15];
        encoded[12] = u[12] ^ u[13] ^ u[14] ^ u[15];
        encoded[13] = u[13] ^ u[15];
        encoded[14] = u[14] ^ u[15];
        encoded[15] = u[15];
        return encoded;
endfunction

function Bit#(32) mulG32(Bit#(32) u);
        Bit#(32) tmp = {mulG16(u[31:16]),mulG16(u[15:0])};
        Bit#(32) encoded = {tmp[31:16], tmp[31:16] ^ tmp[15:0]};
        return encoded;
endfunction

(* noinline *)
function Bit#(64) mulG64(Bit#(64) u);
        Bit#(64) tmp = {mulG32(u[63:32]),mulG32(u[31:0])};
	Bit#(64) encoded = {tmp[63:32], tmp[63:32] ^ tmp[31:0]};
        return encoded;
endfunction

(* noinline *)
function Bit#(128) mulG128(Bit#(128) u);
        Bit#(128) tmp = {mulG64(u[127:64]),mulG64(u[63:0])};
        Bit#(128) encoded = {tmp[127:64], tmp[127:64] ^ tmp[63:0]};
        return encoded;
endfunction

(* noinline *)
function Bit#(256) mulG256(Bit#(256) u);
        Bit#(256) tmp = {mulG128(u[255:128]),mulG128(u[127:0])};
        Bit#(256) encoded = {tmp[255:128], tmp[255:128] ^ tmp[127:0]};
        return encoded;
endfunction

/*
(* noinline *)
function Bit#(256) mulG256_1st(Bit#(256) u);
        Bit#(256) partially_encoded = {mulG64(u[255:192]), mulG64(u[191:128]), mulG64(u[127:64]), mulG64(u[63:0])};
        return partially_encoded;
endfunction

(* noinline *)
function Bit#(256) mulG256_2nd(Bit#(256) u);
        Bit#(256) tmp = {u[255:192], u[255:192] ^ u[191:128], u[127:64], u[127:64] ^ u[63:0]};
        Bit#(256) encoded = {tmp[255:128], tmp[255:128] ^ tmp[127:0]};
        return encoded;
endfunction
*/
function Bit#(8) rate0EncoderN8(Vector#(8, LLR#(n)) llr);
        Bit#(8) hd;
        for (Integer i=0 ; i<8 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
        return mulG8(hd);
endfunction


function Bit#(16) rate0EncoderN16(Vector#(16, LLR#(n)) llr);
        Bit#(16) hd;
        for (Integer i=0 ; i<16 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
        return mulG16(hd);
endfunction

function Bit#(32) rate0EncoderN32(Vector#(32, LLR#(n)) llr);
        Bit#(32) hd;
        for (Integer i=0 ; i<32 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
        return mulG32(hd);
endfunction

function Bit#(64) rate0EncoderN64(Vector#(64, LLR#(n)) llr);
        Bit#(64) hd;
        for (Integer i=0 ; i<64 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
        return mulG64(hd);
	//return hd;
endfunction

function Bit#(128) rate0EncoderN128(Vector#(128, LLR#(n)) llr);
        Bit#(128) hd;
        for (Integer i=0 ; i<128 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
        return mulG128(hd);
        //return hd;
endfunction

function Bit#(256) rate0EncoderN256(Vector#(256, LLR#(n)) llr);
        Bit#(256) hd;
        for (Integer i=0 ; i<256 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
        //return mulG128(hd);
        return hd;
endfunction

function Bit#(8) repspcEncoderN8(Vector#(8, LLR#(n)) llr, Bit#(8) u_hat) provisos(Add#(n,3,m));
        Bit#(4) u_hat_enc = mulG4({1'b0, u_hat[2:0]});
	Bit#(8) u_hat_updated = u_hat;
	Vector#(4, LLR#(TAdd#(n,1))) llr_sign_changed;
        // REPN4 part
        Int#(TAdd#(n,3)) llr_sum = 0;
	Vector#(4, LLR#(TAdd#(n,1))) llr_u = update_LLR_N4(llr, 4'b0, 1'b0);
        for (Integer i=0 ; i<4 ; i=i+1) begin
                llr_sign_changed[i].val = u_hat_enc[i] == 0 ? llr_u[i].val : -llr_u[i].val;
	end
        for (Integer i=0 ; i<4 ; i=i+1)
                llr_sum = llr_sum + signExtend(llr_sign_changed[i].val);
        u_hat_updated[3] = llr_sum >= 0 ? 0 : 1;
        u_hat_updated[2:0] = u_hat[2:0];
	// SPCN4 part
	Vector#(4, LLR#(TAdd#(n,1))) llr_l = update_LLR_N4(llr, mulG4(u_hat_updated[3:0]), 1'b1);
        Bit#(4) hd;
        Vector#(4, LLR#(TAdd#(n,1))) llr_abs;
        Vector#(2, LLR#(TAdd#(n,1))) min_llr_abs_stage1;

        Vector#(2, UInt#(2)) min_idx_stage1;

        UInt#(2) min_idx;
        bit parity;

        for (Integer i=0 ; i<4 ; i=i+1)
                hd[i] = hardDecision(llr_l[i]);
        parity = hd[0] ^ hd[1] ^ hd[2] ^ hd[3] ^ u_hat[4];

        for (Integer i=0 ; i<4 ; i=i+1) begin
                llr_abs[i].is_finite = llr_l[i].is_finite;
                llr_abs[i].val = abs(llr_l[i].val);
        end

        for (Integer i=0 ; i<2 ; i=i+1)
                if (llr_abs[2*i].val <= llr_abs[2*i+1].val) begin
                        min_llr_abs_stage1[i] = llr_abs[2*i];
                        min_idx_stage1[i] = fromInteger(2*i);
                end
                else begin
                        min_llr_abs_stage1[i] = llr_abs[2*i+1];
                        min_idx_stage1[i] = fromInteger(2*i+1);
                end

        if (min_llr_abs_stage1[0].val <= min_llr_abs_stage1[1].val) begin
                min_idx = min_idx_stage1[0];
        end
        else begin
                min_idx = min_idx_stage1[1];
        end
        hd[min_idx] = hd[min_idx] ^ parity;
        u_hat_updated[7:4] = mulG4(hd);
        return u_hat_updated;
endfunction

function Bit#(8) ml2r04EncoderN8(Vector#(8, LLR#(n)) llr, Bit#(8) u_hat) provisos(Add#(n,3,m));
        Bit#(8) u_hat_updated = u_hat;
        // ML2 part
        Vector#(4, LLR#(TAdd#(n,1))) llr_u = update_LLR_N4(llr, 4'b0, 1'b0);

        Vector#(4, Int#(TAdd#(n,3))) llr_sum = replicate(0);
        for (Integer j=0 ; j <= 3 ; j=j+1) begin
                Bit#(4) u_hat_candidate = u_hat[3:0];
                u_hat_candidate[3:2] = fromInteger(j);
                Bit#(4) u_hat_encoded = mulG4(u_hat_candidate);
                for (Integer i=0 ; i<4 ; i=i+1)
                        llr_sum[j] = llr_sum[j] + ((u_hat_encoded[i] == 0) ? signExtend(llr_u[i].val) : signExtend( -llr_u[i].val));
        end
        Vector#(2, Int#(m)) max_llr_stage1 = replicate(0);
        Vector#(2, Bit#(2)) max_idx_stage1 = replicate(0);
        Bit#(2) max_idx = 0;

        for (Integer i=0 ; i<2 ; i=i+1) begin
                if (llr_sum[2*i] >= llr_sum[2*i+1]) begin
                        max_llr_stage1[i] = llr_sum[2*i];
                        max_idx_stage1[i] = fromInteger(2*i);
                end
                else begin
                        max_llr_stage1[i] = llr_sum[2*i+1];
                        max_idx_stage1[i] = fromInteger(2*i+1);
                end
        end
        if (max_llr_stage1[0] >= max_llr_stage1[1])
                max_idx = max_idx_stage1[0];
        else
                max_idx = max_idx_stage1[1];
        u_hat_updated[3:2] = max_idx;

        // R04 part
        Vector#(4, LLR#(TAdd#(n,1))) llr_l = update_LLR_N4(llr, mulG4(u_hat_updated[3:0]), 1'b1);
        Bit#(4) hd = 0;
        for (Integer i=0 ; i<4 ; i=i+1)
                hd[i] = hardDecision(llr_l[i]);
        u_hat_updated[7:4] = mulG4(hd);
        return u_hat_updated;
endfunction


function Bit#(8) repr04EncoderN8(Vector#(8, LLR#(n)) llr, Bit#(8) u_hat) provisos(Add#(n,3,m));
        Bit#(4) u_hat_enc = mulG4({1'b0, u_hat[2:0]});
        Bit#(8) u_hat_updated = u_hat;
        Vector#(4, LLR#(TAdd#(n,1))) llr_sign_changed;
        // REPN4 part
        Int#(TAdd#(n,3)) llr_sum = 0;
        Vector#(4, LLR#(TAdd#(n,1))) llr_u = update_LLR_N4(llr, 4'b0, 1'b0);
        for (Integer i=0 ; i<4 ; i=i+1) begin
                llr_sign_changed[i].val = u_hat_enc[i] == 0 ? llr_u[i].val : -llr_u[i].val;
        end
        for (Integer i=0 ; i<4 ; i=i+1)
                llr_sum = llr_sum + signExtend(llr_sign_changed[i].val);
        u_hat_updated[3] = llr_sum >= 0 ? 0 : 1;
        u_hat_updated[2:0] = u_hat[2:0];
        // R04 part
        Vector#(4, LLR#(TAdd#(n,1))) llr_l = update_LLR_N4(llr, mulG4(u_hat_updated[3:0]), 1'b1);
        Bit#(4) hd = 0;
        for (Integer i=0 ; i<4 ; i=i+1)
                hd[i] = hardDecision(llr_l[i]);
        u_hat_updated[7:4] = mulG4(hd);
        return u_hat_updated;
endfunction

function Bit#(8) r14spcEncoderN8(Vector#(8, LLR#(n)) llr, Bit#(8) u_hat) provisos(Add#(n,3,m));
        Bit#(8) u_hat_updated = u_hat;
        // SPCN4 part
        Vector#(4, LLR#(TAdd#(n,1))) llr_l = update_LLR_N4(llr, mulG4(u_hat_updated[3:0]), 1'b1);
        Bit#(4) hd;
        Vector#(4, LLR#(TAdd#(n,1))) llr_abs;
        Vector#(2, LLR#(TAdd#(n,1))) min_llr_abs_stage1;

        Vector#(2, UInt#(2)) min_idx_stage1;

        UInt#(2) min_idx;
        bit parity;

        for (Integer i=0 ; i<4 ; i=i+1)
                hd[i] = hardDecision(llr_l[i]);
        parity = hd[0] ^ hd[1] ^ hd[2] ^ hd[3] ^ u_hat[4];

        for (Integer i=0 ; i<4 ; i=i+1) begin
                llr_abs[i].is_finite = llr_l[i].is_finite;
                llr_abs[i].val = abs(llr_l[i].val);
        end

        for (Integer i=0 ; i<2 ; i=i+1)
                if (llr_abs[2*i].val <= llr_abs[2*i+1].val) begin
                        min_llr_abs_stage1[i] = llr_abs[2*i];
                        min_idx_stage1[i] = fromInteger(2*i);
                end
                else begin
                        min_llr_abs_stage1[i] = llr_abs[2*i+1];
                        min_idx_stage1[i] = fromInteger(2*i+1);
                end

        if (min_llr_abs_stage1[0].val <= min_llr_abs_stage1[1].val) begin
                min_idx = min_idx_stage1[0];
        end
        else begin
                min_idx = min_idx_stage1[1];
        end
        hd[min_idx] = hd[min_idx] ^ parity;
        u_hat_updated[7:4] = mulG4(hd);
        return u_hat_updated;
endfunction


function Bit#(8) repEncoderN8(Vector#(8, LLR#(n)) llr, Bit#(7) msg) provisos(Add#(n,3,m));
	Bit#(8) u_hat_enc = mulG8({1'b0, msg});
	Vector#(8, LLR#(n)) llr_sign_changed;
	Bit#(8) u_hat = 0;
	Int#(m) llr_sum = 0;
	for (Integer i=0 ; i<8 ; i=i+1)
		llr_sign_changed[i].val = u_hat_enc[i] == 0 ? llr[i].val : -llr[i].val;
	for (Integer i=0 ; i<8 ; i=i+1)
		llr_sum = llr_sum + signExtend(llr_sign_changed[i].val);
	u_hat[7] = llr_sum >= 0 ? 0 : 1;
	u_hat[6:0] = msg;
	return u_hat;	
endfunction

function Bit#(8) ml2EncoderN8(Vector#(8, LLR#(n)) llr, Bit#(8) u_hat) provisos(Add#(n,3,m));
        Vector#(4, Int#(m)) llr_sum = replicate(0);
	for (Integer j=0 ; j <= 3 ; j=j+1) begin
		Bit#(8) u_hat_candidate = u_hat;
		u_hat_candidate[7:6] = fromInteger(j);
		Bit#(8) u_hat_encoded = mulG8(u_hat_candidate);
        	for (Integer i=0 ; i<8 ; i=i+1)
			llr_sum[j] = llr_sum[j] + signExtend((u_hat_encoded[i] == 0) ? llr[i].val : -llr[i].val);
	end
	Vector#(2, Int#(m)) max_llr_stage1 = replicate(0);
	Vector#(2, Bit#(2)) max_idx_stage1 = replicate(0);
	Bit#(2) max_idx = 0;

	for (Integer i=0 ; i<2 ; i=i+1) begin
		if (llr_sum[2*i] >= llr_sum[2*i+1]) begin
			max_llr_stage1[i] = llr_sum[2*i];
			max_idx_stage1[i] = fromInteger(2*i);
		end
		else begin
                	max_llr_stage1[i] = llr_sum[2*i+1];
                	max_idx_stage1[i] = fromInteger(2*i+1);	
		end
	end
	if (max_llr_stage1[0] >= max_llr_stage1[1])
		max_idx = max_idx_stage1[0];
	else
		max_idx = max_idx_stage1[1];
	Bit#(8) u_hat_final = u_hat;
	u_hat_final[7:6] = max_idx;
        return u_hat_final;
endfunction

function Bit#(16) ml2EncoderN16(Vector#(16, LLR#(n)) llr, Bit#(16) u_hat) provisos(Add#(n,4,m));
        Vector#(4, Int#(m)) llr_sum = replicate(0);
        for (Integer j=0 ; j <= 3 ; j=j+1) begin
                Bit#(16) u_hat_candidate = u_hat;
                u_hat_candidate[15:14] = fromInteger(j);
                Bit#(16) u_hat_encoded = mulG16(u_hat_candidate);
                for (Integer i=0 ; i<16 ; i=i+1)
                        llr_sum[j] = llr_sum[j] + signExtend((u_hat_encoded[i] == 0) ? llr[i].val : -llr[i].val);
        end
        Vector#(2, Int#(m)) max_llr_stage1 = replicate(0);
        Vector#(2, Bit#(2)) max_idx_stage1 = replicate(0);
        Bit#(2) max_idx = 0;

        for (Integer i=0 ; i<2 ; i=i+1) begin
                if (llr_sum[2*i] >= llr_sum[2*i+1]) begin
                        max_llr_stage1[i] = llr_sum[2*i];
                        max_idx_stage1[i] = fromInteger(2*i);
                end
                else begin
                        max_llr_stage1[i] = llr_sum[2*i+1];
                        max_idx_stage1[i] = fromInteger(2*i+1);
                end
        end
        if (max_llr_stage1[0] >= max_llr_stage1[1])
                max_idx = max_idx_stage1[0];
        else
                max_idx = max_idx_stage1[1];
        Bit#(16) u_hat_final = u_hat;
        u_hat_final[15:14] = max_idx;
        return u_hat_final;
endfunction

function Bit#(8) ml3EncoderN8(Vector#(8, LLR#(n)) llr, Bit#(8) u_hat) provisos(Add#(n,3,m));
        Vector#(8, Int#(m)) llr_sum = replicate(0);
        for (Integer j=0 ; j <= 7 ; j=j+1) begin
                Bit#(8) u_hat_candidate = u_hat;
                u_hat_candidate[7:5] = fromInteger(j);
                Bit#(8) u_hat_encoded = mulG8(u_hat_candidate);
                for (Integer i=0 ; i<8 ; i=i+1)
                        llr_sum[j] = llr_sum[j] + signExtend((u_hat_encoded[i] == 0) ? llr[i].val : -llr[i].val);
        end
        Vector#(4, Int#(m)) max_llr_stage1 = replicate(0);
        Vector#(4, Bit#(3)) max_idx_stage1 = replicate(0);
        Vector#(2, Int#(m)) max_llr_stage2 = replicate(0);
        Vector#(2, Bit#(3)) max_idx_stage2 = replicate(0);
        Bit#(3) max_idx = 0;

        for (Integer i=0 ; i<4 ; i=i+1) begin
                if (llr_sum[2*i] >= llr_sum[2*i+1]) begin
                        max_llr_stage1[i] = llr_sum[2*i];
                        max_idx_stage1[i] = fromInteger(2*i);
                end
                else begin
                        max_llr_stage1[i] = llr_sum[2*i+1];
                        max_idx_stage1[i] = fromInteger(2*i+1);
                end
        end
        for (Integer i=0 ; i<2 ; i=i+1) begin
                if (max_llr_stage1[2*i] >= max_llr_stage1[2*i+1]) begin
                        max_llr_stage2[i] = max_llr_stage1[2*i];
                        max_idx_stage2[i] = max_idx_stage1[2*i];
                end
                else begin
                        max_llr_stage2[i] = max_llr_stage1[2*i+1];
                        max_idx_stage2[i] = max_idx_stage1[2*i+1];
                end
        end
        if (max_llr_stage2[0] >= max_llr_stage2[1])
                max_idx = max_idx_stage2[0];
        else
                max_idx = max_idx_stage2[1];
        Bit#(8) u_hat_final = u_hat;
        u_hat_final[7:5] = max_idx;
        return u_hat_final;
endfunction

(* noinline *)
function Bit#(8) ml2EncoderN8_LLR13(Vector#(8, LLR#(13)) llr, Bit#(8) u_hat);
        return ml2EncoderN8(llr, u_hat);
endfunction

(* noinline *)
function Bit#(8) ml3EncoderN8_LLR13(Vector#(8, LLR#(13)) llr, Bit#(8) u_hat);
        return ml3EncoderN8(llr, u_hat);
endfunction

(* noinline *)
function Bit#(16) ml2EncoderN16_LLR12(Vector#(16, LLR#(12)) llr, Bit#(16) u_hat);
        return ml2EncoderN16(llr, u_hat);
endfunction

function Bit#(16) repEncoderN16(Vector#(16, LLR#(n)) llr, Bit#(15) msg) provisos(Add#(n,4,m));
        Bit#(16) u_hat_enc = mulG16({1'b0, msg});
        Vector#(16, LLR#(n)) llr_sign_changed;
        Bit#(16) u_hat = 0;
        Int#(m) llr_sum = 0;
        for (Integer i=0 ; i<16 ; i=i+1)
                llr_sign_changed[i].val = u_hat_enc[i] == 0 ? llr[i].val : -llr[i].val;
        for (Integer i=0 ; i<16 ; i=i+1)
                llr_sum = llr_sum + signExtend(llr_sign_changed[i].val);
        u_hat[15] = llr_sum >= 0 ? 0 : 1;
        u_hat[14:0] = msg;
        return u_hat;
endfunction

function Bit#(8) spcEncoderN8(Vector#(8, LLR#(n)) llr, bit u_0);
        Bit#(8) hd;
	Vector#(8, LLR#(n)) llr_abs;
	Vector#(4, LLR#(n)) min_llr_abs_stage1;
        Vector#(2, LLR#(n)) min_llr_abs_stage2;

        Vector#(4, UInt#(3)) min_idx_stage1;
        Vector#(2, UInt#(3)) min_idx_stage2;

	UInt#(3) min_idx;
	bit parity;

	for (Integer i=0 ; i<8 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
	//hd[0] = hd[0] ^ u_0;
	parity = hd[0] ^ hd[1] ^ hd[2] ^ hd[3] ^ hd[4] ^ hd[5] ^ hd[6] ^ hd[7] ^ u_0;

	for (Integer i=0 ; i<8 ; i=i+1) begin
		llr_abs[i].is_finite = llr[i].is_finite;
		llr_abs[i].val = abs(llr[i].val);
	end

	for (Integer i=0 ; i<4 ; i=i+1)
		if (llr_abs[2*i].val <= llr_abs[2*i+1].val) begin
			min_llr_abs_stage1[i] = llr_abs[2*i];
			min_idx_stage1[i] = fromInteger(2*i);
		end
		else begin
                        min_llr_abs_stage1[i] = llr_abs[2*i+1];
                        min_idx_stage1[i] = fromInteger(2*i+1);
		end

        for (Integer i=0 ; i<2 ; i=i+1)
                if (min_llr_abs_stage1[2*i].val <= min_llr_abs_stage1[2*i+1].val) begin
                        min_llr_abs_stage2[i] = min_llr_abs_stage1[2*i];
                        min_idx_stage2[i] = min_idx_stage1[2*i];
                end
                else begin
                        min_llr_abs_stage2[i] = min_llr_abs_stage1[2*i+1];
                        min_idx_stage2[i] = min_idx_stage1[2*i+1];
                end

	if (min_llr_abs_stage2[0].val <= min_llr_abs_stage2[1].val) begin
                min_idx = min_idx_stage2[0];
        end
        else begin
                min_idx = min_idx_stage2[1];
        end
	hd[min_idx] = hd[min_idx] ^ parity;
	let hd_encoded = mulG8(hd);
	//hd_encoded[0] = u_0;
        return hd_encoded;
endfunction

function Bit#(16) spcEncoderN16(Vector#(16, LLR#(n)) llr, bit u_0);
        Bit#(16) hd;
        Vector#(16, LLR#(n)) llr_abs;
        Vector#(8, LLR#(n)) min_llr_abs_stage1;
        Vector#(4, LLR#(n)) min_llr_abs_stage2;
	Vector#(2, LLR#(n)) min_llr_abs_stage3;

        Vector#(8, UInt#(4)) min_idx_stage1;
        Vector#(4, UInt#(4)) min_idx_stage2;
	Vector#(2, UInt#(4)) min_idx_stage3;

        UInt#(4) min_idx;
        bit parity;

        for (Integer i=0 ; i<16 ; i=i+1)
                hd[i] = hardDecision(llr[i]);
        //hd[0] = hd[0] ^ u_0;
        parity = hd[0] ^ hd[1] ^ hd[2] ^ hd[3] ^ hd[4] ^ hd[5] ^ hd[6] ^ hd[7] ^ hd[8] ^ hd[9] ^ hd[10] ^ hd[11] ^ hd[12] ^ hd[13] ^ hd[14] ^ hd[15] ^ u_0;

        for (Integer i=0 ; i<16 ; i=i+1) begin
                llr_abs[i].is_finite = llr[i].is_finite;
                llr_abs[i].val = abs(llr[i].val);
        end

        for (Integer i=0 ; i<8 ; i=i+1)
                if (llr_abs[2*i].val <= llr_abs[2*i+1].val) begin
                        min_llr_abs_stage1[i] = llr_abs[2*i];
                        min_idx_stage1[i] = fromInteger(2*i);
                end
                else begin
                        min_llr_abs_stage1[i] = llr_abs[2*i+1];
                        min_idx_stage1[i] = fromInteger(2*i+1);
                end

        for (Integer i=0 ; i<4 ; i=i+1)
                if (min_llr_abs_stage1[2*i].val <= min_llr_abs_stage1[2*i+1].val) begin
                        min_llr_abs_stage2[i] = min_llr_abs_stage1[2*i];
                        min_idx_stage2[i] = min_idx_stage1[2*i];
                end
                else begin
                        min_llr_abs_stage2[i] = min_llr_abs_stage1[2*i+1];
                        min_idx_stage2[i] = min_idx_stage1[2*i+1];
                end
        for (Integer i=0 ; i<2 ; i=i+1)
                if (min_llr_abs_stage2[2*i].val <= min_llr_abs_stage2[2*i+1].val) begin
                        min_llr_abs_stage3[i] = min_llr_abs_stage2[2*i];
                        min_idx_stage3[i] = min_idx_stage2[2*i];
                end
                else begin
                        min_llr_abs_stage3[i] = min_llr_abs_stage2[2*i+1];
                        min_idx_stage3[i] = min_idx_stage2[2*i+1];
                end

        if (min_llr_abs_stage3[0].val <= min_llr_abs_stage3[1].val) begin
                min_idx = min_idx_stage3[0];
        end
        else begin
                min_idx = min_idx_stage3[1];
        end
        hd[min_idx] = hd[min_idx] ^ parity;
        let hd_encoded = mulG16(hd);
        //hd_encoded[0] = u_0;
        return hd_encoded;
endfunction


/*
function Vector#(128, LLR#(3)) update_LLR_N128(Bit#(256) prev_encoded, Bit#(128) s_hat, bit f_or_g);
        Vector#(128, LLR#(3)) llr_updated;
        for (Integer i=0 ; i<128 ; i=i+1)
                llr_updated[i] = initLLRUpdateN2(prev_encoded[i], prev_encoded[i+128], s_hat[i], f_or_g);
        return llr_updated;
endfunction
*/
function Vector#(128, LLR#(m)) update_LLR_N128(Vector#(256, LLR#(n)) llr_in, Bit#(128) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(128, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<128 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+128], s_hat[i], f_or_g);
        return llr_updated;
endfunction

function Vector#(64, LLR#(m)) update_LLR_N64(Vector#(128, LLR#(n)) llr_in, Bit#(64) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(64, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<64 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+64], s_hat[i], f_or_g);
        return llr_updated;
endfunction

function Vector#(32, LLR#(3)) update_LLR_N32_init(Bit#(64) prev_encoded, Bit#(32) s_hat, bit f_or_g);
        Vector#(32, LLR#(3)) llr_updated;
        for (Integer i=0 ; i<32 ; i=i+1)
                llr_updated[i] = initLLRUpdateN2(prev_encoded[i], prev_encoded[i+32], s_hat[i], f_or_g);
        return llr_updated;
endfunction

function Vector#(32, LLR#(m)) update_LLR_N32(Vector#(64, LLR#(n)) llr_in, Bit#(32) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(32, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<32 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+32], s_hat[i], f_or_g);
        return llr_updated;
endfunction

function Vector#(16, LLR#(m)) update_LLR_N16(Vector#(32, LLR#(n)) llr_in, Bit#(16) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(16, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<16 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+16], s_hat[i], f_or_g);
        return llr_updated;
endfunction

function Vector#(8, LLR#(m)) update_LLR_N8(Vector#(16, LLR#(n)) llr_in, Bit#(8) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(8, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<8 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+8], s_hat[i], f_or_g);
        return llr_updated;
endfunction

function Vector#(4, LLR#(m)) update_LLR_N4(Vector#(8, LLR#(n)) llr_in, Bit#(4) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(4, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<4 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+4], s_hat[i], f_or_g);
        return llr_updated;
endfunction

function Vector#(2, LLR#(m)) update_LLR_N2(Vector#(4, LLR#(n)) llr_in, Bit#(2) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(2, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<2 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+2], s_hat[i], f_or_g);
        return llr_updated;
endfunction

(* noinline *)
function Bit#(4) take_at_N4 (Bit#(6) sub_cw_counter, Codeword u_hat);
	Bit#(4) u_hat_N4 = case(sub_cw_counter)
			6'd0: u_hat[3:0];
			6'd1: u_hat[7:4];
			6'd2: u_hat[11:8];
			6'd3: u_hat[15:12];
			6'd4: u_hat[19:16];
			6'd5: u_hat[23:20];
			6'd6: u_hat[27:24];
			6'd7: u_hat[31:28];
			6'd8: u_hat[35:32];
			6'd9: u_hat[39:36];
			6'd10: u_hat[43:40];
			6'd11: u_hat[47:44];
			6'd12: u_hat[51:48];
			6'd13: u_hat[55:52];
			6'd14: u_hat[59:56];
			6'd15: u_hat[63:60];
			6'd16: u_hat[67:64];
			6'd17: u_hat[71:68];
			6'd18: u_hat[75:72];
			6'd19: u_hat[79:76];
			6'd20: u_hat[83:80];
			6'd21: u_hat[87:84];
			6'd22: u_hat[91:88];
			6'd23: u_hat[95:92];
			6'd24: u_hat[99:96];
			6'd25: u_hat[103:100];
			6'd26: u_hat[107:104];
			6'd27: u_hat[111:108];
			6'd28: u_hat[115:112];
			6'd29: u_hat[119:116];
			6'd30: u_hat[123:120];
			6'd31: u_hat[127:124];
			6'd32: u_hat[131:128];
			6'd33: u_hat[135:132];
			6'd34: u_hat[139:136];
			6'd35: u_hat[143:140];
			6'd36: u_hat[147:144];
			6'd37: u_hat[151:148];
			6'd38: u_hat[155:152];
			6'd39: u_hat[159:156];
			6'd40: u_hat[163:160];
			6'd41: u_hat[167:164];
			6'd42: u_hat[171:168];
			6'd43: u_hat[175:172];
			6'd44: u_hat[179:176];
			6'd45: u_hat[183:180];
			6'd46: u_hat[187:184];
			6'd47: u_hat[191:188];
			6'd48: u_hat[195:192];
			6'd49: u_hat[199:196];
			6'd50: u_hat[203:200];
			6'd51: u_hat[207:204];
			6'd52: u_hat[211:208];
			6'd53: u_hat[215:212];
			6'd54: u_hat[219:216];
			6'd55: u_hat[223:220];
			6'd56: u_hat[227:224];
			6'd57: u_hat[231:228];
			6'd58: u_hat[235:232];
			6'd59: u_hat[239:236];
			6'd60: u_hat[243:240];
			6'd61: u_hat[247:244];
			6'd62: u_hat[251:248];
			6'd63: u_hat[255:252];
		endcase;
	return u_hat_N4;
endfunction

(* noinline *)
function Codeword update_at_N4 (Bit#(6) sub_cw_counter, Codeword u_hat_old, Bit#(4) u_hat_N4);
	Codeword u_hat = u_hat_old;
	case(sub_cw_counter)
			6'd0: u_hat[3:0]=u_hat_N4;
			6'd1: u_hat[7:4]=u_hat_N4;
			6'd2: u_hat[11:8]=u_hat_N4;
			6'd3: u_hat[15:12]=u_hat_N4;
			6'd4: u_hat[19:16]=u_hat_N4;
			6'd5: u_hat[23:20]=u_hat_N4;
			6'd6: u_hat[27:24]=u_hat_N4;
			6'd7: u_hat[31:28]=u_hat_N4;
			6'd8: u_hat[35:32]=u_hat_N4;
			6'd9: u_hat[39:36]=u_hat_N4;
			6'd10: u_hat[43:40]=u_hat_N4;
			6'd11: u_hat[47:44]=u_hat_N4;
			6'd12: u_hat[51:48]=u_hat_N4;
			6'd13: u_hat[55:52]=u_hat_N4;
			6'd14: u_hat[59:56]=u_hat_N4;
			6'd15: u_hat[63:60]=u_hat_N4;
			6'd16: u_hat[67:64]=u_hat_N4;
			6'd17: u_hat[71:68]=u_hat_N4;
			6'd18: u_hat[75:72]=u_hat_N4;
			6'd19: u_hat[79:76]=u_hat_N4;
			6'd20: u_hat[83:80]=u_hat_N4;
			6'd21: u_hat[87:84]=u_hat_N4;
			6'd22: u_hat[91:88]=u_hat_N4;
			6'd23: u_hat[95:92]=u_hat_N4;
			6'd24: u_hat[99:96]=u_hat_N4;
			6'd25: u_hat[103:100]=u_hat_N4;
			6'd26: u_hat[107:104]=u_hat_N4;
			6'd27: u_hat[111:108]=u_hat_N4;
			6'd28: u_hat[115:112]=u_hat_N4;
			6'd29: u_hat[119:116]=u_hat_N4;
			6'd30: u_hat[123:120]=u_hat_N4;
			6'd31: u_hat[127:124]=u_hat_N4;
			6'd32: u_hat[131:128]=u_hat_N4;
			6'd33: u_hat[135:132]=u_hat_N4;
			6'd34: u_hat[139:136]=u_hat_N4;
			6'd35: u_hat[143:140]=u_hat_N4;
			6'd36: u_hat[147:144]=u_hat_N4;
			6'd37: u_hat[151:148]=u_hat_N4;
			6'd38: u_hat[155:152]=u_hat_N4;
			6'd39: u_hat[159:156]=u_hat_N4;
			6'd40: u_hat[163:160]=u_hat_N4;
			6'd41: u_hat[167:164]=u_hat_N4;
			6'd42: u_hat[171:168]=u_hat_N4;
			6'd43: u_hat[175:172]=u_hat_N4;
			6'd44: u_hat[179:176]=u_hat_N4;
			6'd45: u_hat[183:180]=u_hat_N4;
			6'd46: u_hat[187:184]=u_hat_N4;
			6'd47: u_hat[191:188]=u_hat_N4;
			6'd48: u_hat[195:192]=u_hat_N4;
			6'd49: u_hat[199:196]=u_hat_N4;
			6'd50: u_hat[203:200]=u_hat_N4;
			6'd51: u_hat[207:204]=u_hat_N4;
			6'd52: u_hat[211:208]=u_hat_N4;
			6'd53: u_hat[215:212]=u_hat_N4;
			6'd54: u_hat[219:216]=u_hat_N4;
			6'd55: u_hat[223:220]=u_hat_N4;
			6'd56: u_hat[227:224]=u_hat_N4;
			6'd57: u_hat[231:228]=u_hat_N4;
			6'd58: u_hat[235:232]=u_hat_N4;
			6'd59: u_hat[239:236]=u_hat_N4;
			6'd60: u_hat[243:240]=u_hat_N4;
			6'd61: u_hat[247:244]=u_hat_N4;
			6'd62: u_hat[251:248]=u_hat_N4;
			6'd63: u_hat[255:252]=u_hat_N4;
	endcase
        return u_hat;
endfunction

endpackage

