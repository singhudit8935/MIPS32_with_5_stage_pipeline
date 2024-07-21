`include "processor.v"

module test();
    reg clk1, clk2,PC;
    integer k;
    pipe_MIPS32 mips(clk1, clk2);

    initial begin 
        clk1=0; 
        clk2=0;
        repeat(20) begin 
            #5 clk1=1; #5 clk1=0;  // generating two phase clocks
            #5 clk2=1; #5 clk2=0;
        end
    end

    initial begin 
        for(k=0; k<31; k=k+1) begin 
            mips.REGISTER[k]=k; // innitiasiling the GPR 
            // here we are reffereing to pipl_MIPS32 's registers which are 
            // general purpose register.. 
            // we do refernce using as here we want to refer REGISTER of mips ie pipe_MIPS
            // so we used the mps. REGISTER[k]
        end
        mips.MEM[0]= 32'h2801000a;  //ADDI R1, R0,10   here we are feeding instructions in memory
        mips.MEM[1]= 32'h28020012 ; //ADDI R2, R0, 20
        mips.MEM[2]= 32'h28030019  ; // ADDI R3, R0, 25
        // dummy instruction inserted to deal with data hazard
        mips.MEM[3]= 32'h0ce77800;/// **DUMMY INSTRUCTOIN** OR R7, R7, R7  
        mips.MEM[4]= 32'h0ce7800; // dummy instru
        mips.MEM[5]= 32'h00222000;  // ADD R4, R1, R2
        mips.MEM[6]= 32'h0ce77800;  // or instruction DUMMY]
        mips.MEM[7]= 32'h00832800;   // ADD R5, R4, R3
        mips.MEM[8]= 32'hfc000000;    // HLT

        // setting halted , oc and branck taken to 0
        mips.HALTED=0;
        mips.PC=0;
        mips. BRANCH_TAKEN=0;

        #280
        for(k=0; k<8; k=k+1) begin 
             $display("R%1d - %2d", k, mips. REGISTER[k]);
        end

        end

        initial begin 
            $dumpfile("mips.vcd");
            $dumpvars(0,test);
            $dumpvars(0,test.PC);
            #300 $finish;
        end


endmodule
