module ALU_Control_Unit (
    input  wire [1:0] ALU_Op,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] ALU_Cntrl
);

    localparam [1:0]
        R_type  = 2'b10,
        IS_type = 2'b00,
        B_type  = 2'b01;

    // ALU operation codes sent to the ALU module.
    localparam [3:0]
        ALU_AND = 4'b0000,
        ALU_OR  = 4'b0001,
        ALU_ADD = 4'b0010,
        ALU_SUB = 4'b0110;

    // RISC-V R-type funct field = {funct7[5], funct3}.
    // These are the INSTRUCTION encodings -- separate from the ALU codes above.
    localparam [3:0]
        RV_ADD = 4'b0000,   // funct7[5]=0, funct3=000
        RV_SUB = 4'b1000,   // funct7[5]=1, funct3=000
        RV_OR  = 4'b0110,   // funct7[5]=0, funct3=110
        RV_AND = 4'b0111;   // funct7[5]=0, funct3=111

    wire [3:0] funct = {funct7[5], funct3};

    always @(*) begin
        if (ALU_Op == R_type) begin
            case (funct)
                RV_ADD: ALU_Cntrl = ALU_ADD;
                RV_SUB: ALU_Cntrl = ALU_SUB;
                RV_OR:  ALU_Cntrl = ALU_OR;
                RV_AND: ALU_Cntrl = ALU_AND;
                default: ALU_Cntrl = 4'bx;
            endcase
        end
        else if (ALU_Op == IS_type)
            ALU_Cntrl = ALU_ADD;
        else if (ALU_Op == B_type)
            ALU_Cntrl = ALU_SUB;
        else
            ALU_Cntrl = 4'bx;
    end
endmodule