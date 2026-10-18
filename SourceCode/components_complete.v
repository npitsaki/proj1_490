// this one just passes along the pc as it comes in on it'sinput wire to it's output register
//  which the IM and +2 adder take as input via a wire in the outer/main cpu module.
// NOTE: don't forget the Jump and Branch conditions have to be handled combinationally before arriving
//  at the program_counter input.
module program_counter (input wire[15:0] input_pc, output reg[15:0] output_pc, input wire clock);
    always @(posedge clock) begin
      output_pc <= input_pc;
    end
endmodule


// 16 bit unsigned adder, no carry out
module adder_u16bit (input wire[15:0] input_a, input wire[15:0] input_b, output wire[15:0] result);
    // unsigned and overflows at 16-bits
    assign result = input_a + input_b;
endmodule


// 16 bit signed sign extention (needed to sign extend immediate offset values and jump addresses and branch offsets)
//  so maybe? need a signal to differentiate between extending 4-bit and 12-bit values? (yeah, gonna pass a signal to let us know which to user)
module sign_extension_sl6bit (
    input  wire[15:0]  in,
    input  wire jump,       // control signal that indicates a jump thus we need to sign extend a 12 vs 4 bit number now
    output wire[15:0] out
);
    // either it's a jump and we make 16 bits from 12 bits, or we make 16 bits from from 4 bits
    if (jump) begin
        assign out <= { {4{in[11]}}, in[11:0]}
    end
    else begin
        assign out <= { {12{in[3]}}, in[3:0]};
    end
endmodule


// the instruction is indexed from the lut im then put onto the output register for a wire to
//  attach to and send to other components for decoding
// (NOTE: instruction memory is only word addressable, data memory is byte addressable)
module instruction_memory (input wire[15:0] cur_pc, output reg[15:0] cur_instruction);
    // need minimum of 64 memory locations here
    integer i;  // loop index
    reg [15:0] im [0:63];   // our instruction memory (note: "[0:63] means the first element in memory is at address 0."")
    // initialize the instruction memory to all zeroes? 
    //  (probably should load it from a file on the computer i think for testing/possibly for final version?)
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            im[i] = 16'h0000;
        end
    end

    // notes suggest using readmemb and readmemh commands to initialize memory
    // also say i can do the initial block like above... but for testing a file would be nice.
    always @(*) begin
        cur_instruction = im[cur_pc]; //right now i'm allowing for all 16-bits of memory locations, only need 64 total tho (so 6-bits needed)
    end
endmodule


//  NOTE: "ALU DOES NOT NEED TO HANDLE CARRY AND OVERFLOW CONDITIONS"
// 16-bit ALU
//  alu_op is 2-bit to select between + (add, lw, sw, addi), - (sub), << (sll), and & (and).
//  (other effective addresses for jumps and branches are done with dedicated adders outside the alu... that's the plan rn at least).
module alu (input wire[15:0] input_a, input wire[15:0] input_b, input wire[1:0] alu_op, output reg[15:0] result);
    // sensitivity here is cur_pc i think but for now just do * for all
    always @(*) begin
    // note alu_op is determined by the control unit using the opcode and function codes in the cu decode stage
        case (alu_op)
            2'b00  : result = input_a + input_b;
            2'b01  : result = input_a - input_b;
            2'b10  : result = input_a << input_b;   // assuming input_a and input_b are unsigned here... not sure if we should only use the lowest 4 bits for the shift here...
            2'b11  : result = input_a & input_b;    // bitwise and, inputs interpreted as unsigned
            default  : result = 16'hFFFF;  // set to default to flag value of FFFF
        endcase
    end
endmodule


// the instruction is indexed from the lut im then put onto the output register for a wire to
//  attach to and send to other components for decoding
// (NOTE: instruction memory is only word addressable, data memory is byte addressable)

// just noticed... notes says control lines to choose between read and write,
//  but i only have a write line... don't think i NEED a read line since it's a binary
//  condition but look into it if becomes a problem.
module register_file (input wire clock, input wire[3:0] read_reg_1, input wire[3:0] read_reg_2, input wire[3:0] write_reg, input wire[15:0] write_data, input wire reg_write, output wire[15:0] read_data_1, output wire[15:0] read_data_2);
    integer i;  // loop index
    reg [15:0] rf [0:15];   // our register file with 16 locations (note: "[0:63] means the first element in memory is at address 0."")
   
    // initialize the register file to all zeroes? 
    //  (probably should load it from a file on the computer i think for testing/possibly for final version?)
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            //rf[i] = 16'h0000;
            rf[i] = i;
        end
    end

    // not sure about the ordering here... does the data have to come out before writing
    //  is finished or can we read from reg 4 and write to reg 4? not sure the way it'll work
    //  i think either it reads reg 4 and outputs the data on read data 1 then changes the
    //  value at reg 4 on the clock edge? but idk for sure...
    // the rf always outputs data to the read data... so combinational?
    assign read_data_1 = rf[read_reg_1];
    assign read_data_2 = rf[read_reg_2];

    // we only write when we need to/on the clock edge... so sequential?
    always @(posedge clock) begin
    // handle the sequential stuff here? (the register write basically)
        if (reg_write) begin
            rf[write_reg] <= write_data;
        end
    end
endmodule


module data_memory (input wire clock, input wire[15:0] address, input wire[15:0] data_in, input wire mem_read, input wire mem_write, output wire[15:0] data_out);
    // need minimum of 64 memory locations here
    integer i;  // loop index
    reg [15:0] dm [0:63];   // our instruction memory (note: "[0:63] means the first element in memory is at address 0."")
    // initialize the instruction memory to all zeroes? 
    //  (probably should load it from a file on the computer i think for testing/possibly for final version?)
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            //im[i] = 16'h0000;
            dm[i] = i;
        end
    end


    // alright... so the values read from data memory are always available,
    //  but the values we write to memory are only written on a clock edge...
    //  so we do both sequential and combinational steps i think
    /*
    always @(*) begin
        if (mem_read) begin
            data_out = dm[address];
        end
        else if (mem_write) begin
            dm[address] = data_in;
        end
    end
    */
    // sequential write
    always @(posedge clock) begin
        if (mem_write) begin
            dm[address] <= data_in;
        end
    end

    // combinational read
    //  gives error about compile time
    /*
    if (mem_read) begin 
        assign data_out = dm[address];
    end
    */
    assign data_out = (mem_read) ? dm[address] : 16'h0000;
endmodule



// we have to output all the control signals based on the opcode and funct values
//  (so i have to figure all of these out exactly first)
// (not sure if the control signals are asynchronous and register file related outputs are synchronous just yet...)
module control_unit (
    input wire clock, 
    input wire[15:0] cur_instruction, 
    // all the bit chunks which are assigned on basis of opcode/instruction type.
    // ACUTALLY, starting to think this should be done in the top level... (when i think of the hardware needed to split the instruction it just makes more sense for it
    //  to be at the cpu level rather within the control unit... basically from the IM we get the instruction in full but then we physically split it on the way to the register file
    //  and control unit)
    output wire[3:0] rs_out, 
    output wire[3:0] rt_out, 
    output wire[3:0] immediate_out, 
    output wire[11:0] address_out, 
    // now all the control signals
    //output wire reg_dst,   // actually don't think we need this since there's only an rt/rd (there's only two registers in the instruction itself, one source/rt always becomes a destination/rd)
    output wire mem_read,
    output wire mem_write,
    output wire reg_write,
    output wire jump,
    output wire branch,
    output wire[1:0] alu_op  
    );

// think this will all be in an always @(*) block since it's combinational logic
    // check opcode first (cur_instruction[15:12]), then function code where necessary (when opcode is 0000)
    // not sure if this works well after synthesis/if this is the best way to write the cu code rn...
    case (cur_instruction[15:12])
        4'b0000  : begin // inst - funct, add - 0000, sub = 0001, sll - 0010, and - 0011. all R-type.
            case (cur_instruction[3:0])
                4'b0000 : begin     // add
                    mem_read = 0;
                    mem_write = 0;
                    reg_write = 1;
                    jump = 0;
                    branch = 0;
                    alu_op = 2'b00;  
                end;
                4'b0001 : begin     // sub
                    mem_read = 0;
                    mem_write = 0;
                    reg_write = 1;
                    jump = 0;
                    branch = 0;
                    alu_op = 2'b01;  
                end;
                4'b0010 : begin     // sll
                    mem_read = 0;
                    mem_write = 0;
                    reg_write = 1;
                    jump = 0;
                    branch = 0;
                    alu_op = 2'b10;  
                end;
                4'b0011 : begin     // and
                    mem_read = 0;
                    mem_write = 0;
                    reg_write = 1;
                    jump = 0;
                    branch = 0;
                    alu_op = 2'b11;  
                end;
            endcase
        end; 
        4'b0001  : begin        // lw
            mem_read = 1;
            mem_write = 0;
            reg_write = 1;
            jump = 0;
            branch = 0;
            alu_op = 2'b00;  
        end;
        4'b0010  : begin        // sw
            mem_read = 0;
            mem_write = 1;
            reg_write = 0;
            jump = 0;
            branch = 0;
            alu_op = 2'b00;  
        end; 
        4'b0011  : begin        // addi
            mem_read = 0;
            mem_write = 0;
            reg_write = 1;
            jump = 0;
            branch = 0;
            alu_op = 2'b00;  
        end; 
        4'b0100  : begin        // beq
            mem_read = 0;
            mem_write = 0;
            reg_write = 0;
            jump = 0;
            branch = 1;
            alu_op = 2'b00;  
        end; 
        4'b0101  : begin        // bne
            mem_read = 0;
            mem_write = 0;
            reg_write = 0;
            jump = 0;
            branch = 1;
            alu_op = 2'b00;  
        end;
        4'b0110  : begin        // jmp
            mem_read = 0;
            mem_write = 0;
            reg_write = 0;
            jump = 1;
            branch = 0;
            alu_op = 2'b00;  
        end; 
        default  : begin        // default if unexpected opcode occurs
            mem_read = 0;
            mem_write = 0;
            reg_write = 0;
            jump = 0;
            branch = 0;
            alu_op = 2'b00;  
        end;  
    endcase
endmodule

// used before one of the alu inputs after the sign extension to select between sign extended immediates or addresses, OR the data read from the rt register.
module mux2_1 (input wire[15:0] rt_data, input wire[15:0] immmediate_or_address, input wire select, output wire[15:0] selection);
    assign selection = (select) ? rt_data : immmediate_or_address;
endmodule