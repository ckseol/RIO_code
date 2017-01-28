package RIO_subencoder_1st;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

import Polar_codec_common_revised::*;

typedef enum { ENC_RUNNING_MAIN, ENC_RUNNING_GEN_FINAL_LLR, ENC_RUNNING_R0N32, ENC_RUNNING_N16,
               ENC_RUNNING_N32, ENC_RUNNING_N8, ENC_RUNNING_N4, ENC_DONE} State deriving(Bits, Eq);

interface RIOSubEncoder1stIfc;
	method Action load_LLR(LLR_vector#(8) llr);
	method Action load_u_hat(Codeword u);
	method Action load_msg_ind(Codeword msg_ind);
	method Action load_enc_instruction(SubcodeInstruction enc_instr);
	method ActionValue#(Codeword) get_encoded_result();
	//method ActionValue#(Codeword) get_updated_u_hat();
endinterface: RIOSubEncoder1stIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRIOSubEncoder1st(RIOSubEncoder1stIfc);

	// input/output
	FIFO#(LLR_vector#(8)) llr_in <- mkPipelineFIFO;
	//FIFOF#(Codeword) u_hat_in <- mkFIFOF1;
	FIFO#(Codeword) msg_ind_in <- mkPipelineFIFO;
	FIFO#(SubcodeInstruction) enc_instr_in <- mkPipelineFIFO;
	
	FIFO#(Codeword) encoded <- mkPipelineFIFO;
	FIFO#(Codeword) u_hat_out <- mkFIFO1;
	// for internal use
	//FIFO#(LLR_N4#(14)) fifo_llr_N4 <- mkFIFO1;
	//FIFO#(Bit#(4)) fifo_u_hat_N4 <- mkFIFO1;

	Reg#(LLR_N8#(13)) reg_llr_N8_u <- mkRegU;
	Reg#(Bit#(8)) reg_u_hat_N8_u <- mkReg(0);

        Reg#(LLR_N8#(13)) reg_llr_N8_l0 <- mkRegU;
        Reg#(LLR_N8#(13)) reg_llr_N8_l1 <- mkRegU;
        Reg#(Bit#(8)) reg_u_hat_N8_l <- mkReg(0);
	Reg#(Bit#(8)) reg_s_hat_N8 <- mkReg(0);

        Reg#(LLR_N16#(12)) reg_llr_N16_u <- mkRegU;
        Reg#(Bit#(16)) reg_u_hat_N16_u <- mkReg(0);

        Reg#(LLR_N16#(12)) reg_llr_N16_l0 <- mkRegU;
        Reg#(LLR_N16#(12)) reg_llr_N16_l1 <- mkRegU;
        Reg#(Bit#(16)) reg_u_hat_N16_l <- mkReg(0);
        Reg#(Bit#(16)) reg_s_hat_N16 <- mkReg(0);

    //    FIFO#(LLR_N16#(12)) fifo_llr_N16 <- mkFIFO1;
       // FIFO#(Bit#(16)) fifo_u_hat_N16 <- mkFIFO1;

//	Reg#(LLR_N32#(11)) reg_llr_N32 <- mkRegU;

        Reg#(LLR_N32#(11)) reg_llr_N32_u <- mkRegU;
        //Reg#(Bit#(32)) reg_u_hat_N32_u <- mkReg(0);

        Reg#(LLR_N32#(11)) reg_llr_N32_l0 <- mkRegU;
        Reg#(LLR_N32#(11)) reg_llr_N32_l1 <- mkRegU;
        //Reg#(Bit#(32)) reg_u_hat_N32_l <- mkReg(0);
        //Reg#(Bit#(32)) reg_s_hat_N32 <- mkReg(0);


	Reg#(Codeword) u_hat <- mkReg(0);
	Reg#(Bit#(6)) sub_cw_counter <- mkReg(0);
	Reg#(UInt#(6)) instr_counter <- mkReg(0);

	Reg#(State) state <- mkReg(ENC_RUNNING_MAIN);

	rule stateEncRunningMain (state == ENC_RUNNING_MAIN);
		let enc_instr = enc_instr_in.first;
		let current_instr = enc_instr.instructionVector[instr_counter];
		
	//	$display("%d", current_instr);
		case (current_instr)
                        R1N128   : begin
                                        sub_cw_counter <= sub_cw_counter + 32;
                                        instr_counter <= instr_counter + 1;
                                        state <= ENC_RUNNING_MAIN;
                                end
                        R1N64   : begin
                                        sub_cw_counter <= sub_cw_counter + 16;
                                        instr_counter <= instr_counter + 1;
                                        state <= ENC_RUNNING_MAIN;
                                end
                        R1N32	: begin
                                        sub_cw_counter <= sub_cw_counter + 8;
                                        instr_counter <= instr_counter + 1;
                                        state <= ENC_RUNNING_MAIN;
                                end
                        R1N16	: begin
                                        sub_cw_counter <= sub_cw_counter + 4;
                                        instr_counter <= instr_counter + 1;
                                        state <= ENC_RUNNING_MAIN;
                                end
                        R1N8	: begin
                                        sub_cw_counter <= sub_cw_counter + 2;
                                        instr_counter <= instr_counter + 1;					
                                        state <= ENC_RUNNING_MAIN;
                                end
                        R1N4    : begin
                                        sub_cw_counter <= sub_cw_counter + 1;
                                        instr_counter <= instr_counter + 1;
                                        state <= ENC_RUNNING_MAIN;
                                end
                        R0N128   : begin
                                        let s_hat_N128 = mulG128(u_hat[127:0]);
                                        let llr_N128 = update_LLR_N128(llr_in.first, s_hat_N128, sub_cw_counter[5]);
                                        //fifo_llr_N32.enq(llr_N32);

                                        let u_hat_N128 = rate0EncoderN128(llr_N128);
                                        Codeword u_hat_tmp = u_hat;
                                        case(sub_cw_counter[5])
                                                1'b0: u_hat_tmp[127:0] = u_hat_N128;
                                                1'b1: u_hat_tmp[255:128] = u_hat_N128;
                                        endcase
                                        u_hat <= u_hat_tmp;
                                        if (sub_cw_counter[5] == 1'b1)
                                                state <= ENC_DONE;
                                        else begin
                                                sub_cw_counter <= sub_cw_counter + 32;
                                                instr_counter <= instr_counter + 1;
                                                state <= ENC_RUNNING_MAIN;
                                        end
                                end

                        R0N64   : begin
                                        let s_hat_N128 = mulG128(u_hat[127:0]);
                                        let llr_N128 = update_LLR_N128(llr_in.first, s_hat_N128, sub_cw_counter[5]);

                                        let s_hat_N64 = mulG64(case(sub_cw_counter[5])
									1'b0: u_hat[63:0];
									1'b1: u_hat[191:128];
								endcase);
                                        let llr_N64 = update_LLR_N64(llr_N128, s_hat_N64, sub_cw_counter[4]);

                                        let u_hat_N64 = rate0EncoderN64(llr_N64);
                                        Codeword u_hat_tmp = u_hat;
                                        case(sub_cw_counter[5:4])
                                                2'd0: u_hat_tmp[63:0] = u_hat_N64;
                                                2'd1: u_hat_tmp[127:64] = u_hat_N64;
                                                2'd2: u_hat_tmp[191:128] = u_hat_N64;
                                                2'd3: u_hat_tmp[255:192] = u_hat_N64;
                                        endcase
                                        u_hat <= u_hat_tmp;
                                        if (sub_cw_counter[5:4] == 2'd3)
                                                state <= ENC_DONE;
                                        else begin
                                                sub_cw_counter <= sub_cw_counter + 16;
                                                instr_counter <= instr_counter + 1;
                                                state <= ENC_RUNNING_MAIN;
                                        end
                                end


                        R0N32, R0N16, R0N8, REPN16, REPN8, SPCN16, SPCN8, REPSPCN8, R14SPCN8, ML2R04N8, REPR04N8, ML2N16, ML2N8, ML3N8: begin
					let u_hat_N128 = sub_cw_counter[5]==1'b0 ? u_hat[127:0] : u_hat[255:128];
					let u_hat_N64 = sub_cw_counter[4]==1'b0 ? u_hat_N128[63:0] : u_hat_N128[127:64];

                                        let s_hat_N128 = mulG128(u_hat[127:0]);
                                        let llr_N128 = update_LLR_N128(llr_in.first, s_hat_N128, sub_cw_counter[5]);

                                        let s_hat_N64 = mulG64(u_hat_N128[63:0]);
                                        let llr_N64 = update_LLR_N64(llr_N128, s_hat_N64, sub_cw_counter[4]);

                                        let s_hat_N32 = mulG32(u_hat_N64[31:0]);
                                        let llr_N32 = update_LLR_N32(llr_N64, s_hat_N32, sub_cw_counter[3]);

					if (current_instr == R0N32) begin

                                        	let u_hat_N32_new = rate0EncoderN32(llr_N32);
                                        	Codeword u_hat_tmp = u_hat;
                                        	case(sub_cw_counter[5:3])
                                                	3'd0: u_hat_tmp[31:0] = u_hat_N32_new;
                                                	3'd1: u_hat_tmp[63:32] = u_hat_N32_new;
                                                	3'd2: u_hat_tmp[95:64] = u_hat_N32_new;
                                                	3'd3: u_hat_tmp[127:96] = u_hat_N32_new;
                                                	3'd4: u_hat_tmp[159:128] = u_hat_N32_new;
                                                	3'd5: u_hat_tmp[191:160] = u_hat_N32_new;
                                                	3'd6: u_hat_tmp[223:192] = u_hat_N32_new; 
                                                	3'd7: u_hat_tmp[255:224] = u_hat_N32_new;
                                        	endcase
                                        	u_hat <= u_hat_tmp;
                                        	if (sub_cw_counter[5:3] == 3'd7)
                                                	state <= ENC_DONE;
                                        	else begin
                                                	sub_cw_counter <= sub_cw_counter + 8;
                                                	instr_counter <= instr_counter + 1;
                                                	state <= ENC_RUNNING_MAIN;
                                        	end
					end
					else begin
                                         //       let u_hat_N32 = sub_cw_counter[3]==1'b0 ? u_hat_N64[31:0] : u_hat_N64[63:32];
                                          //      reg_llr_N32 <= llr_N32;
					//	state <= ENC_RUNNING_N32;						
	                                        let u_hat_N32_u = u_hat_N64[31:0];
        	                                let u_hat_N32_l = u_hat_N64[63:32];

                                        //fifo_llr_N16.enq(llr_N16);
                                        //fifo_u_hat_N16.enq(u_hat_N16);
	                                        let llr_N32_l0 = update_LLR_N32(llr_N64, 32'h0000_0000, 1'b1); //sub_cw_counter[1]);
        	                                let llr_N32_l1 = update_LLR_N32(llr_N64, 32'hffff_ffff, 1'b1); //sub_cw_counter[1]);

        	                                if (sub_cw_counter[3] == 1'b0) begin
                	                                let llr_N32_u = update_LLR_N32(llr_N64, 0, 1'b0); //sub_cw_counter[1]);
                        	                        reg_llr_N32_u <= llr_N32_u;
                                	                //reg_u_hat_N32_u <= u_hat_N32_u;
                                	        end
                                       		//else begin
                                                //	reg_s_hat_N32 <= mulG32(u_hat_N32_u);
                                        	//end

                                        	reg_llr_N32_l0 <= llr_N32_l0;
                                        	reg_llr_N32_l1 <= llr_N32_l1;
                                        	//reg_u_hat_N32_l <= u_hat_N32_l;
						state <= ENC_RUNNING_N32;
					end
                                end
		endcase
	endrule: stateEncRunningMain


	rule stateEncRunningN32 (state == ENC_RUNNING_N32);
                let u_hat_N128 = sub_cw_counter[5]==1'b0 ? u_hat[127:0] : u_hat[255:128];
                let u_hat_N64 = sub_cw_counter[4]==1'b0 ? u_hat_N128[63:0] : u_hat_N128[127:64];
                let u_hat_N32 = sub_cw_counter[3]==1'b0 ? u_hat_N64[31:0] : u_hat_N64[63:32];

                let enc_instr = enc_instr_in.first;
                let current_instr = enc_instr.instructionVector[instr_counter];
		//let llr_N32 = reg_llr_N32;

                LLR_N32#(11) llr_N32;
                if (sub_cw_counter[3] == 1'b0) begin
                        llr_N32 = reg_llr_N32_u;
                end
                else begin
                        LLR_N32#(11) llr_N32_l0 = reg_llr_N32_l0;
                        LLR_N32#(11) llr_N32_l1 = reg_llr_N32_l1;
                        let s_hat_N32 = mulG32(u_hat_N64[31:0]);//reg_s_hat_N32;
                        for (Integer i=0 ; i<=31 ; i=i+1)
                                llr_N32[i] = s_hat_N32[i] == 1'b0 ? llr_N32_l0[i] : llr_N32_l1[i];
                end
          //      $display("Running @N32: %d", current_instr);
		//R0N16, R0N8, REPN16, REPN8, SPCN16, SPCN8, REPSPCN8, FCN4

                case (current_instr)
			R0N32	: begin
                                        let u_hat_N32_new = rate0EncoderN32(llr_N32);
                                        Codeword u_hat_tmp = u_hat;
                                        case(sub_cw_counter[5:3])
 	                	               	3'd0: u_hat_tmp[31:0] = u_hat_N32_new;
        	                               	3'd1: u_hat_tmp[63:32] = u_hat_N32_new;
                	                       	3'd2: u_hat_tmp[95:64] = u_hat_N32_new;
                                               	3'd3: u_hat_tmp[127:96] = u_hat_N32_new;
                                               	3'd4: u_hat_tmp[159:128] = u_hat_N32_new;
                                               	3'd5: u_hat_tmp[191:160] = u_hat_N32_new;
                                               	3'd6: u_hat_tmp[223:192] = u_hat_N32_new;
                                               	3'd7: u_hat_tmp[255:224] = u_hat_N32_new;
                                        endcase
                                        u_hat <= u_hat_tmp;
                                        if (sub_cw_counter[5:3] == 3'd7)
                                               	state <= ENC_DONE;
                                        else begin
                                               	sub_cw_counter <= sub_cw_counter + 8;
                                                instr_counter <= instr_counter + 1;
						if (sub_cw_counter[3] == 1'b1)	
                                               		state <= ENC_RUNNING_MAIN;
						else 
							state <= ENC_RUNNING_N32;						
                                        end
				end
                        R1N32   : begin
                                        sub_cw_counter <= sub_cw_counter + 8;
                                        instr_counter <= instr_counter + 1;
                                        //if (sub_cw_counter[2] == 1'b1) fifo_llr_N32.deq();
                                        if (sub_cw_counter[3] == 1'b1)
                                                state <= ENC_RUNNING_MAIN;
                                        else
                                                state <= ENC_RUNNING_N32;
                                end
                        R1N16   : begin
                                        sub_cw_counter <= sub_cw_counter + 4;
                                        instr_counter <= instr_counter + 1;
					//if (sub_cw_counter[2] == 1'b1) fifo_llr_N32.deq();
					if (sub_cw_counter[3:2] == 2'd3)
                                        	state <= ENC_RUNNING_MAIN;
					else
						state <= ENC_RUNNING_N32;
                                end
                        R1N8    : begin
                                        sub_cw_counter <= sub_cw_counter + 2;
                                        instr_counter <= instr_counter + 1;
                                        //if (sub_cw_counter[2:1] == 2'd3) fifo_llr_N32.deq();
                                        if (sub_cw_counter[3:1] == 3'd7)
                                                state <= ENC_RUNNING_MAIN;
                                        else
                                                state <= ENC_RUNNING_N32;

                                end
                        R1N4    : begin
                                        sub_cw_counter <= sub_cw_counter + 1;
                                        instr_counter <= instr_counter + 1;
                                        //if (sub_cw_counter[2:0] == 3'd7) fifo_llr_N32.deq();
                                        if (sub_cw_counter[3:0] == 4'd15)
                                                state <= ENC_RUNNING_MAIN;
                                        else
                                                state <= ENC_RUNNING_N32;
                                end
                        R0N16 :  begin
			                let s_hat_N16 = mulG16(u_hat_N32[15:0]);
                			let llr_N16 = update_LLR_N16(llr_N32, s_hat_N16, sub_cw_counter[2]);
		                	let u_hat_N16 = rate0EncoderN16(llr_N16);

                			Codeword u_hat_tmp = u_hat;
                			case(sub_cw_counter[5:2])
                        			4'd0: u_hat_tmp[15:0] = u_hat_N16;
                        			4'd1: u_hat_tmp[31:16] = u_hat_N16;
                        			4'd2: u_hat_tmp[47:32] = u_hat_N16;
                        			4'd3: u_hat_tmp[63:48] = u_hat_N16;
                        			4'd4: u_hat_tmp[79:64] = u_hat_N16;
                        			4'd5: u_hat_tmp[95:80] = u_hat_N16;
                        			4'd6: u_hat_tmp[111:96] = u_hat_N16;
                        			4'd7: u_hat_tmp[127:112] = u_hat_N16;
                        			4'd8: u_hat_tmp[143:128] = u_hat_N16;
                        			4'd9: u_hat_tmp[159:144] = u_hat_N16;
                        			4'd10: u_hat_tmp[175:160] = u_hat_N16;
                        			4'd11: u_hat_tmp[191:176] = u_hat_N16;
                        			4'd12: u_hat_tmp[207:192] = u_hat_N16;
                        			4'd13: u_hat_tmp[223:208] = u_hat_N16;
                        			4'd14: u_hat_tmp[239:224] = u_hat_N16;
                        			4'd15: u_hat_tmp[255:240] = u_hat_N16;
                			endcase
                			u_hat <= u_hat_tmp;			             

					//if (sub_cw_counter[2] == 1'b1) fifo_llr_N32.deq();
                			if (sub_cw_counter[5:2] == 4'd15) 
                        			state <= ENC_DONE;
                			else begin
                        			sub_cw_counter <= sub_cw_counter + 4;
                        			instr_counter <= instr_counter + 1;
						if (sub_cw_counter[3:2] == 2'd3)
                        				state <= ENC_RUNNING_MAIN;
						else 
							state <= ENC_RUNNING_N32;
                			end
                           	end

                        REPN16, ML2N16, SPCN16 :  begin
					let u_hat_N16_u = u_hat_N32[15:0];
                                        let u_hat_N16_l = u_hat_N32[31:16];

					//fifo_llr_N16.enq(llr_N16);
					//fifo_u_hat_N16.enq(u_hat_N16);
                                        let llr_N16_l0 = update_LLR_N16(llr_N32, 16'h0000, 1'b1); //sub_cw_counter[1]);
                                        let llr_N16_l1 = update_LLR_N16(llr_N32, 16'hffff, 1'b1); //sub_cw_counter[1]);

                                        if (sub_cw_counter[2] == 1'b0) begin
                                                let llr_N16_u = update_LLR_N16(llr_N32, 0, 1'b0); //sub_cw_counter[1]);
                                                reg_llr_N16_u <= llr_N16_u;
                                                reg_u_hat_N16_u <= u_hat_N16_u;
                                        end
                                        else begin
                                                reg_s_hat_N16 <= mulG16(u_hat_N16_u);
                                        end

                                        reg_llr_N16_l0 <= llr_N16_l0;
                                        reg_llr_N16_l1 <= llr_N16_l1;
                                        reg_u_hat_N16_l <= u_hat_N16_l;

					//if (sub_cw_counter[2] == 1'b1) fifo_llr_N32.deq();					
					state <= ENC_RUNNING_N16;			
                                end

			R0N8, REPN8,  ML2N8, ML3N8, SPCN8, REPSPCN8, R14SPCN8, ML2R04N8, REPR04N8: begin
                			let u_hat_N16 = sub_cw_counter[2] == 1'b0 ? u_hat_N32[15:0] : u_hat_N32[31:16];
                			//let u_hat_N8 = sub_cw_counter[1] == 1'b0 ? u_hat_N16[7:0] : u_hat_N16[15:8];
                                        let u_hat_N8_u = u_hat_N16[7:0];
                                        let u_hat_N8_l = u_hat_N16[15:8];

                			let s_hat_N16 = mulG16(u_hat_N32[15:0]);
                			let llr_N16 = update_LLR_N16(llr_N32, s_hat_N16, sub_cw_counter[2]);
					
                			//let s_hat_N8 = mulG8(u_hat_N16[7:0]);
                			//let llr_N8_u = update_LLR_N8(llr_N16, 0, 1'b0); //sub_cw_counter[1]);
					let llr_N8_l0 = update_LLR_N8(llr_N16, 8'h00, 1'b1); //sub_cw_counter[1]);
					let llr_N8_l1 = update_LLR_N8(llr_N16, 8'hff, 1'b1); //sub_cw_counter[1]);

					if (sub_cw_counter[1] == 1'b0) begin	
						let llr_N8_u = update_LLR_N8(llr_N16, 0, 1'b0); //sub_cw_counter[1]);
                				reg_llr_N8_u <= llr_N8_u;
	               				reg_u_hat_N8_u <= u_hat_N8_u;
					end
					else begin
						reg_s_hat_N8 <= mulG8(u_hat_N8_u);
					end

                                        reg_llr_N8_l0 <= llr_N8_l0;
					reg_llr_N8_l1 <= llr_N8_l1;
                                        reg_u_hat_N8_l <= u_hat_N8_l;			

					//if (sub_cw_counter[2:1] == 2'd3) fifo_llr_N32.deq();
					state <= ENC_RUNNING_N8;
				end
		endcase
	endrule
	
        rule stateEncRunningEncoderN8 (state == ENC_RUNNING_N8);
	//	$display("Encoding@N8 upper, %d", sub_cw_counter);

		LLR_N8#(13) llr_N8;
		Bit#(8) current_u_hat_N8;
		if (sub_cw_counter[1] == 1'b0) begin
                	llr_N8 = reg_llr_N8_u;
			current_u_hat_N8 = reg_u_hat_N8_u;
		end
		else begin
                	LLR_N8#(13) llr_N8_l0 = reg_llr_N8_l0;
                	LLR_N8#(13) llr_N8_l1 = reg_llr_N8_l1;
                	let s_hat_N8 = reg_s_hat_N8;
                	current_u_hat_N8 = reg_u_hat_N8_l;
                	for (Integer i=0 ; i<=7 ; i=i+1)
                        	llr_N8[i] = s_hat_N8[i] == 1'b0 ? llr_N8_l0[i] : llr_N8_l1[i];
		end

                let enc_instr = enc_instr_in.first;
                let current_instr = enc_instr.instructionVector[instr_counter];

                let u_hat_N8 = case(current_instr)
                                     	R0N8: rate0EncoderN8(llr_N8);
                                     	REPN8: repEncoderN8(llr_N8, current_u_hat_N8[6:0]);
					SPCN8: spcEncoderN8(llr_N8, current_u_hat_N8[0]);
					ML2N8: ml2EncoderN8_LLR13(llr_N8, current_u_hat_N8);
                                     	ML3N8: ml3EncoderN8_LLR13(llr_N8, current_u_hat_N8);
				     	REPSPCN8: repspcEncoderN8(llr_N8, current_u_hat_N8);
                                        R14SPCN8: r14spcEncoderN8(llr_N8, current_u_hat_N8);
                                        ML2R04N8: ml2r04EncoderN8(llr_N8, current_u_hat_N8);
                                        REPR04N8: repr04EncoderN8(llr_N8, current_u_hat_N8);
                                     	default: current_u_hat_N8;
                               endcase;
		reg_s_hat_N8 <= mulG8(u_hat_N8);

                Codeword u_hat_tmp = u_hat;
                case(sub_cw_counter[5:1])
                        5'd0: u_hat_tmp[7:0]=u_hat_N8;
                        5'd1: u_hat_tmp[15:8]=u_hat_N8;
                        5'd2: u_hat_tmp[23:16]=u_hat_N8;
                        5'd3: u_hat_tmp[31:24]=u_hat_N8;
                        5'd4: u_hat_tmp[39:32]=u_hat_N8;
                        5'd5: u_hat_tmp[47:40]=u_hat_N8;
                        5'd6: u_hat_tmp[55:48]=u_hat_N8;
                        5'd7: u_hat_tmp[63:56]=u_hat_N8;
                        5'd8: u_hat_tmp[71:64]=u_hat_N8;
                        5'd9: u_hat_tmp[79:72]=u_hat_N8;
                        5'd10: u_hat_tmp[87:80]=u_hat_N8;
                        5'd11: u_hat_tmp[95:88]=u_hat_N8;
                        5'd12: u_hat_tmp[103:96]=u_hat_N8;
                        5'd13: u_hat_tmp[111:104]=u_hat_N8;
                        5'd14: u_hat_tmp[119:112]=u_hat_N8;
                        5'd15: u_hat_tmp[127:120]=u_hat_N8;
                        5'd16: u_hat_tmp[135:128]=u_hat_N8;
                        5'd17: u_hat_tmp[143:136]=u_hat_N8;
                        5'd18: u_hat_tmp[151:144]=u_hat_N8;
                        5'd19: u_hat_tmp[159:152]=u_hat_N8;
                        5'd20: u_hat_tmp[167:160]=u_hat_N8;
                        5'd21: u_hat_tmp[175:168]=u_hat_N8;
                        5'd22: u_hat_tmp[183:176]=u_hat_N8;
                        5'd23: u_hat_tmp[191:184]=u_hat_N8;
                        5'd24: u_hat_tmp[199:192]=u_hat_N8;
                        5'd25: u_hat_tmp[207:200]=u_hat_N8;
                        5'd26: u_hat_tmp[215:208]=u_hat_N8;
                        5'd27: u_hat_tmp[223:216]=u_hat_N8;
                        5'd28: u_hat_tmp[231:224]=u_hat_N8;
                        5'd29: u_hat_tmp[239:232]=u_hat_N8;
                        5'd30: u_hat_tmp[247:240]=u_hat_N8;
                        5'd31: u_hat_tmp[255:248]=u_hat_N8;
                endcase
                u_hat <= u_hat_tmp;

                if (sub_cw_counter[5:1] == 5'd31) begin
                        state <= ENC_DONE;
                end
                else begin
                        sub_cw_counter <= sub_cw_counter + 2;
                        instr_counter <= instr_counter + 1;
			//if (sub_cw_counter[2:1] == 2'd2) fifo_llr_N32.deq();

                        if (sub_cw_counter[3:1] == 3'd7)
                                state <= ENC_RUNNING_MAIN;			
			else if (sub_cw_counter[1] == 1'b0)
				state <= ENC_RUNNING_N8;
                        else
                                state <= ENC_RUNNING_N32;
                end
        endrule: stateEncRunningEncoderN8


	rule stateEncRunningRate0EncoderN16 (state == ENC_RUNNING_N16);
                LLR_N16#(12) llr_N16;
                Bit#(16) u_hat_N16_old;
                if (sub_cw_counter[2] == 1'b0) begin
                        llr_N16 = reg_llr_N16_u;
                        u_hat_N16_old = reg_u_hat_N16_u;
                end
                else begin
                        LLR_N16#(12) llr_N16_l0 = reg_llr_N16_l0;
                        LLR_N16#(12) llr_N16_l1 = reg_llr_N16_l1;
                        let s_hat_N16 = reg_s_hat_N16;
                        u_hat_N16_old = reg_u_hat_N16_l;
                        for (Integer i=0 ; i<=15 ; i=i+1)
                                llr_N16[i] = s_hat_N16[i] == 1'b0 ? llr_N16_l0[i] : llr_N16_l1[i];
                end
	
                let enc_instr = enc_instr_in.first;
                let current_instr = enc_instr.instructionVector[instr_counter];

                let u_hat_N16 = case(current_instr)
                                     REPN16: repEncoderN16(llr_N16, u_hat_N16_old[14:0]);
                                     SPCN16: spcEncoderN16(llr_N16, u_hat_N16_old[0]);
				     ML2N16: ml2EncoderN16_LLR12(llr_N16, u_hat_N16_old);
                                     default:u_hat_N16_old;
                               endcase;

                Codeword u_hat_tmp = u_hat;
                case(sub_cw_counter[5:2])
                	4'd0: u_hat_tmp[15:0] = u_hat_N16;
                	4'd1: u_hat_tmp[31:16] = u_hat_N16;
                	4'd2: u_hat_tmp[47:32] = u_hat_N16;
                	4'd3: u_hat_tmp[63:48] = u_hat_N16;
                	4'd4: u_hat_tmp[79:64] = u_hat_N16;
                	4'd5: u_hat_tmp[95:80] = u_hat_N16;
                	4'd6: u_hat_tmp[111:96] = u_hat_N16;
                	4'd7: u_hat_tmp[127:112] = u_hat_N16;
                        4'd8: u_hat_tmp[143:128] = u_hat_N16;
                        4'd9: u_hat_tmp[159:144] = u_hat_N16;
                        4'd10: u_hat_tmp[175:160] = u_hat_N16;
                        4'd11: u_hat_tmp[191:176] = u_hat_N16;
                        4'd12: u_hat_tmp[207:192] = u_hat_N16;
                        4'd13: u_hat_tmp[223:208] = u_hat_N16;
                        4'd14: u_hat_tmp[239:224] = u_hat_N16;
                        4'd15: u_hat_tmp[255:240] = u_hat_N16;
                endcase
                u_hat <= u_hat_tmp;

		if (sub_cw_counter[5:2] == 4'd15)
			state <= ENC_DONE;
		else begin
			sub_cw_counter <= sub_cw_counter + 4;
			instr_counter <= instr_counter + 1;
			if (sub_cw_counter[3:2] == 2'd3)
				state <= ENC_RUNNING_MAIN;
                        else begin
		                let next_instr = enc_instr.instructionVector[instr_counter+1];
				if ((next_instr == REPN16 || next_instr == ML2N16 || next_instr == SPCN16) && sub_cw_counter[2] == 1'b0)
					state <= ENC_RUNNING_N16;
				else
					state <= ENC_RUNNING_N32;
			end
		end			
	endrule	

        rule stateEncDone (state == ENC_DONE);
                let encoded_u_hat = mulG256(u_hat);
                encoded.enq(encoded_u_hat);
                llr_in.deq();
                msg_ind_in.deq();
                enc_instr_in.deq();
                instr_counter <= 0;
                state <= ENC_RUNNING_MAIN;
        endrule: stateEncDone

        method Action load_LLR(LLR_vector#(8) llr);
		llr_in.enq(llr);
	endmethod

        method Action load_u_hat(Codeword u);
		u_hat <= u;
		//u_hat_in.enq(u);
	endmethod

        method Action load_msg_ind(Codeword msg_ind);
		msg_ind_in.enq(msg_ind);
	endmethod

        method Action load_enc_instruction(SubcodeInstruction enc_instr);
		enc_instr_in.enq(enc_instr);
		sub_cw_counter <= enc_instr.offset;
	endmethod

        method ActionValue#(Codeword) get_encoded_result();
		let encoded_result = encoded.first; encoded.deq();
		return encoded_result;
	endmethod

        //method ActionValue#(Codeword) get_updated_u_hat();
	//	let u_hat_result = u_hat_out.first; u_hat_out.deq();
	//	return u_hat_result;
	//endmethod
			
endmodule: mkRIOSubEncoder1st

endpackage: RIO_subencoder_1st
