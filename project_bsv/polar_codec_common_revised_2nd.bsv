
Integer codeword_len = 32;
Integer message_len = 6;

typedef Bit#(32) Codeword;
typedef Bit#(6) Message;

typedef struct {bit is_finite; Int#(n) val;} LLR#(numeric type n) deriving(Bits, Eq);  

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
	LLR#(m) g_a_b;//LLR#(m){is_finite: 0, val: 0};
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
	return llr.val > 0 ? 0 : 1;
endfunction: hardDecision

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

function Bit#(64) mulG64(Bit#(64) u);
        Bit#(64) tmp = {mulG32(u[63:32]),mulG32(u[31:0])};
	Bit#(64) encoded = {tmp[63:32], tmp[63:32] ^ tmp[31:0]};
        return encoded;
endfunction

function Bit#(128) mulG128(Bit#(128) u);
        Bit#(128) tmp = {mulG64(u[127:64]),mulG64(u[63:0])};
        Bit#(128) encoded = {tmp[127:64], tmp[127:64] ^ tmp[63:0]};
        return encoded;
endfunction


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
        //return mulG64(hd);
	return hd;
endfunction

function Bit#(8) repEncoderN8(Vector#(8, LLR#(n)) llr, Bit#(7) msg) provisos(Add#(n,3,m));
	Bit#(8) u_hat_enc = mulG8({1'b0, msg});
	Vector#(8, LLR#(n)) llr_sign_changed;
	Bit#(8) u_hat = 0;
	Int#(m) llr_sum = 0;
	for (Integer i=0 ; i<8 ; i=i+1) begin
		llr_sign_changed[i].is_finite = llr[i].is_finite;
		llr_sign_changed[i].val = u_hat_enc[i] == 0 ? llr[i].val : -llr[i].val;
	end
	for (Integer i=0 ; i<8 ; i=i+1)
		llr_sum = llr_sum + signExtend(llr_sign_changed[i].val);
	u_hat[7] = llr_sum > 0 ? 0 : 1;
	u_hat[6:0] = msg;
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
	hd[0] = hd[0] ^ u_0;
	parity = hd[0] ^ hd[1] ^ hd[2] ^ hd[3] ^ hd[4] ^ hd[5] ^ hd[6] ^ hd[7];

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
	
	case(min_idx)
		3'd0: hd[0] = hd[0] ^ parity;
                3'd1: hd[1] = hd[1] ^ parity;
                3'd2: hd[2] = hd[2] ^ parity;
                3'd3: hd[3] = hd[3] ^ parity;
                3'd4: hd[4] = hd[4] ^ parity;
                3'd5: hd[5] = hd[5] ^ parity;
                3'd6: hd[6] = hd[6] ^ parity;
                3'd7: hd[7] = hd[7] ^ parity;
	endcase
	let hd_encoded = mulG8(hd);
	hd_encoded[0] = u_0;
        return hd_encoded;
endfunction

function Bit#(4) spcEncoderN4(Vector#(4, LLR#(n)) llr, bit u_0);
        Bit#(4) hd;
        Vector#(4, LLR#(n)) llr_abs;
        Vector#(2, LLR#(n)) min_llr_abs_stage1;

        Vector#(2, UInt#(2)) min_idx_stage1;

        UInt#(2) min_idx;
        bit parity;

        for (Integer i=0 ; i<4 ; i=i+1) 
                hd[i] = hardDecision(llr[i]);
        hd[0] = hd[0] ^ u_0;
        parity = hd[0] ^ hd[1] ^ hd[2] ^ hd[3];

        for (Integer i=0 ; i<4 ; i=i+1) begin
		llr_abs[i].is_finite = llr[i].is_finite;
                llr_abs[i].val = abs(llr[i].val);
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

        case(min_idx)
                2'd0: hd[0] = hd[0] ^ parity;
                2'd1: hd[1] = hd[1] ^ parity;
                2'd2: hd[2] = hd[2] ^ parity;
                2'd3: hd[3] = hd[3] ^ parity;
        endcase
        let hd_encoded = mulG4(hd);
        hd_encoded[0] = u_0;
        return hd_encoded;
endfunction

function Bit#(4) repEncoderN4(Vector#(4, LLR#(n)) llr, Bit#(3) msg) provisos(Add#(n,2,m));
        Bit#(4) u_hat_enc = mulG4({1'b0, msg});
        Vector#(4, LLR#(n)) llr_sign_changed;
        Bit#(4) u_hat = 0;
        Int#(m) llr_sum = 0;
        for (Integer i=0 ; i<4 ; i=i+1) begin
		llr_sign_changed[i].is_finite = llr[i].is_finite;
                llr_sign_changed[i].val = u_hat_enc[i] == 0 ? llr[i].val : -llr[i].val;
	end
        for (Integer i=0 ; i<4 ; i=i+1)
                llr_sum = llr_sum + signExtend(llr_sign_changed[i].val);
        u_hat[3] = llr_sum > 0 ? 0 : 1;
        u_hat[2:0] = msg;
        return u_hat;
endfunction

function Vector#(4, LLR#(m)) update_LLR_N4(Vector#(8, LLR#(n)) llr_in, Bit#(4) s_hat, bit f_or_g) provisos(Add#(n,1,m));
        Vector#(4, LLR#(m)) llr_updated;
        for (Integer i=0 ; i<4 ; i=i+1)
                llr_updated[i] = llrUpdateN2(llr_in[i], llr_in[i+4], s_hat[i], f_or_g);
        return llr_updated;
endfunction

