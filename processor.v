module pipe_MIPS32(clk1, clk2);
    input clk1, clk2; // creating a two phase clock
    reg[31:0] PC, IF_ID_IR, IF_ID_NPC;
    reg[31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_IMM;
    reg[31:0] EX_MEM_IR, EX_MEM_ALUOUT, EX_MEM_B;
    reg[2:0] ID_EX_TYPE,EX_MEM_TYPE, MEM_WB_TYPE;  // these type are the instruction types like Register-register, register-memory like these
    reg EX_MEM_COND;
    reg[31:0] MEM_WB_IR, MEM_WB_ALUOUT, MEM_WB_LMD;

    reg[31:0] REGISTER[0:31];  //register bank of 32 x32
    reg[31:0] MEM[0:1023]; // memory of 1024 x 32

    parameter ADD= 6'b000000, SUB=6'b000001, AND=6'b000010, OR=6'b000011,
    SLT=6'b000100, MUL=6'b000101, HLT=6'b111111, LW=6'b001000, SW=6'b001001, ADDI=6'b001010,
    SUBI=6'b001011, SLTI=6'b001100,
    BNEQZ=6'b001101, BEQZ=6'b001110;

    parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010, STORE=3'b011, 
    BRANCH=3'b100, HALT=3'b101;

    reg HALTED; // set after the HLT instruction iis completed in the WB Stage ie last stage of pipeling
    reg BRANCH_TAKEN; // required to disable instruciton after the branch

    //IF stage
    always @(posedge clk1) begin 
        if(HALTED==0) begin // all this process will occur when halted flag is nt set to q
            if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_COND==1)) || 
             ((EX_MEM_IR[31:26]== BNEQZ) || ( EX_MEM_COND==0))) 
             // this shows when we have tor branch 
            // this condition is that (A==0) where A is the source register 1 ie content of source register is all zero
            // we can branch 1. branch if condition is equal to 1 or brnch if not qual to 0
            // and we also have some condition to fullfill adn double verify the code
             begin 
                IF_ID_IR <= #2 MEM[EX_MEM_ALUOUT];  // here we are not taking next address from PC
                // rather we're taking next instruction from the output of excution stage and from the output of alu
                BRANCH_TAKEN<= #2 1'b1;
                IF_ID_NPC<= #2 EX_MEM_ALUOUT +1; // new oc will be updated to adress we fot from alu output +1
                PC<= #2 EX_MEM_ALUOUT +1;
             end
            else begin 
                IF_ID_IR<= #2 MEM[PC];
                IF_ID_NPC<= #2 PC+1;
                PC<= #2 PC+1;
            end
        end
    end

    // insstruction decode stage
    // in decode we first decode the OPCODE, in this case we have already didi it
    // we prefetch the source and destination registers
    // we're sign extending the 16 bit imm field
    always @(negedge clk2) begin 
        if (HALTED==0) begin 
            if(IF_ID_IR[25:21]==5'b00000) ID_EX_A<=0;  // here we re checking if opcode meant register[0] ehic contains 0,
            // if this conditoin is found be tur, then we directly assign it
            else ID_EX_A <=#2 REGISTER[IF_ID_IR[25:21]]; // loading the value of sources regiser in A
            //"RS1" SRCE REGISTER 1

            if(IF_ID_IR[20:16]== 5'b00000) ID_EX_B<=0; // same happen for B as if A
            else  ID_EX_B<= #2 REGISTER[IF_ID_IR[20:16]]; //"sorce register 2 "B" loaded wih value 
            

            ID_EX_NPC<= #2 IF_ID_NPC;
            ID_EX_IR <= #2 IF_ID_IR;
            ID_EX_IMM <=#2 {{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}} ;// SIGN BIT EXTENSION TO MAKE IT 32 BIT LONG
            //here we are replicating sign bit sixteen times which is indicated by the first terem in the bracket==

            case(IF_ID_IR[31:26]) // here we are checking the the meaning of OPCODe, whzt does opcode what to say
            // it meant to explain what does it signify
                ADD, SUB, AND, OR, SLT, MUL: ID_EX_TYPE <= #2 RR_ALU; // register register alu instruction
                ADDI, SUBI, SLTI : ID_EX_TYPE <=#2 RM_ALU; // register memory
                LW: ID_EX_TYPE<= #2 LOAD; // LW MEANS LOAD WORD
                SW: ID_EX_TYPE <=#2 STORE;
                BNEQZ, BEQZ : ID_EX_TYPE <= #2 BRANCH;
                HLT: ID_EX_TYPE <= #2 HALT;
                default: ID_EX_TYPE <= #2 HALT;  // THIS IS THE CASE OF INVALID OPCODE

            endcase
        end
    end

        // now EXECUTION STAGE
        // this is triggered by clock 1

        always @(posedge clk1) begin
            if (HALTED==0) begin 
                EX_MEM_TYPE <= #2 ID_EX_TYPE;
                EX_MEM_IR <= #2 ID_EX_IR;
                BRANCH_TAKEN<= #2 0;

                case(ID_EX_TYPE)
                    RR_ALU: begin 
                        case(ID_EX_IR[31:26]) //OPCODE
                            ADD: EX_MEM_ALUOUT<= ID_EX_A + ID_EX_B;
                            SUB: EX_MEM_ALUOUT<= ID_EX_A - ID_EX_B;
                            AND: EX_MEM_ALUOUT<= ID_EX_A & ID_EX_B;
                            OR: EX_MEM_ALUOUT<= ID_EX_A | ID_EX_B;
                            SLT: EX_MEM_ALUOUT<= ID_EX_A < ID_EX_B;
                            MUL: EX_MEM_ALUOUT<= ID_EX_A * ID_EX_B;
                            default: EX_MEM_ALUOUT<= 32'hxxxxxxxx;


                        endcase
                    end
                    RM_ALU: begin 
                        case(ID_EX_IR[31:26]) //opcode
                            ADDI: EX_MEM_ALUOUT<= ID_EX_A + ID_EX_IMM;
                            SUBI: EX_MEM_ALUOUT<= ID_EX_A - ID_EX_IMM;
                            SLTI: EX_MEM_ALUOUT<= ID_EX_A < ID_EX_IMM;
                            default: EX_MEM_ALUOUT<= 32'hxxxxxxxx;
                            

                        endcase
                    end

                    LOAD, STORE:
                        begin 
                            EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_IMM;
                            EX_MEM_B <= #2 ID_EX_B;
                        end
                    
                    BRANCH: begin
                        EX_MEM_ALUOUT <= #2 ID_EX_NPC + ID_EX_IMM;
                        EX_MEM_COND <= #2 (ID_EX_A ==0);
                    end
                    
                endcase
            end 
        end

        //mem stage

        always @(posedge clk2) begin
            if (HALTED==0 )begin 
                MEM_WB_TYPE <=#2 EX_MEM_TYPE; // these paramets are forwarded to next stage
                MEM_WB_IR <= #2 EX_MEM_IR;// this also

                case(EX_MEM_TYPE) 
                    RR_ALU, RM_ALU:
                        MEM_WB_ALUOUT <= #2 EX_MEM_ALUOUT;
                    LOAD: MEM_WB_LMD <= #2 MEM[EX_MEM_ALUOUT];
                    STORE: if(BRANCH_TAKEN==0) begin // DISABEL WRITE when it is o
                            MEM[EX_MEM_ALUOUT] <= #2 EX_MEM_B;
                    end
                endcase
            end
        end

        //WB stage(write back stage)
        always @(posedge clk1) begin 
            if(BRANCH_TAKEN==0 ) begin 
                case(MEM_WB_TYPE==0) // DISABLE WRITE IF BRANCH IS TAKEN
                    RR_ALU: REGISTER[MEM_WB_IR[15:11]] <=#2 MEM_WB_ALUOUT; // "rd"
                    RM_ALU: REGISTER[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOUT; //" rt"\
                    LOAD: REGISTER[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD; // "RT"
                    HALT: HALTED <= #2 1'b1;
                endcase
            end
        end
        
endmodule
