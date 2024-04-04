`ifndef define_svh
`define define_svh
/******************************Global******************************/
parameter  Rst_Enable      =   1'b0;            
parameter  Rst_Disable     =   1'b1;            
parameter  Write_Enable    =   1'b1;            
parameter  Write_Disable   =   1'b0;            
parameter  Read_Enable     =   1'b1;            
parameter  Read_Disable    =   1'b0;            
parameter  Sext_Enable     =   1'b1;            
parameter  Shift_Enable    =   1'b1;            
parameter  Imm_Enable      =   1'b1;            
parameter  Upper_Enable    =   1'b1;            

/**************************************************************/
parameter  Data_Bus        =   32;              
parameter  Addr_Bus        =   32;              
parameter  RegAddr_Bus     =   5;               
parameter  Aluop_Bus       =   8;               
parameter  Alutype_Bus     =   3;               
parameter  Exccode_Bus     =   5;               

/************************************************************/
parameter  Zero_Word       =   32'h0000_0000;    
parameter  Initial_PC      =   32'hbfc0_0000;    

//ERET鎸囦??
parameter  ERET_Code       =   32'b010000_1_0000000000000000000_011000;

/******************************branch**************************/
parameter  BLTZ_rt  = 6'b00000; 
parameter  BGEZ_rt  = 6'b00001; 
parameter  BLTZAL_rt= 6'b10000; 
parameter  BGEZAL_rt= 6'b10001; 

parameter  BLTZ  = 6'b000001; 
parameter  BLTZAL= 6'b000001; 
parameter  BGEZ  = 6'b000001; 
parameter  BGEZAL= 6'b000001; 

//tequan
parameter ERET  = 6'b010000;
parameter MFC0  = 6'b010000;
parameter MTC0  = 6'b010000;
//TLB
parameter TLB   = 6'b010000;

/********************************************************/
parameter EXC_ADDR      = 32'hBFC00380;
parameter EXC_INT_ADDR  = 32'hBFC00380;

/*****************OPCODE***************/
typedef enum logic [5 : 0] {
    //branch
    BEQ   = 6'b000100, 
    BNE   = 6'b000101, 
    BLEZ  = 6'b000110, 
    BGTZ  = 6'b000111, 
    //j
    J     = 6'b000010, 
    JAL   = 6'b000011, 
    // alu
    ADDI  = 6'b001000,
    ADDIU = 6'b001001,
    SLTI  = 6'b001010,
    SLTIU = 6'b001011,
    ANDI  = 6'b001100,
    ORI   = 6'b001101,
    XORI  = 6'b001110,
    LUI   = 6'b001111,
    // load/store
    LB    = 6'b100000,
    LBU   = 6'b100100,
    LH    = 6'b100001,
    LHU   = 6'b100101,
    LW    = 6'b100011,
    SB    = 6'b101000,
    SH    = 6'b101001,
    SW    = 6'b101011,
    // 0815
    LWL   = 6'b100010,
    LWR   = 6'b100110,
    SWL   = 6'b101010,
    SWR   = 6'b101110,

    MUL   = 6'b011100,
    CACHE = 6'b101111
} opcode_enum;

/*****************FUNC***************/
typedef enum logic [5 : 0] {
    ADD     = 6'b100000,
    ADDU    = 6'b100001,
    SUB     = 6'b100010,
    SUBU    = 6'b100011,
    SLT     = 6'b101010,
    SLTU    = 6'b101011,
    AND     = 6'b100100,
    OR      = 6'b100101,
    NOR     = 6'b100111,
    XOR     = 6'b100110,
    //yiwei
    SLL     = 6'b000000,
    SRL     = 6'b000010,
    SRA     = 6'b000011,
    SLLV    = 6'b000100,
    SRLV    = 6'b000110,
    SRAV    = 6'b000111,
    //j
    JR      = 6'b001000,
    JALR    = 6'b001001,
    //zixian
    SYSCALL = 6'b001100,
    BREAK   = 6'b001101,
    //*??
    MULT    = 6'b011000,
    MULTU   = 6'b011001,
    DIV     = 6'b011010,
    DIVU    = 6'b011011,
    //HI/LO
    MFHI    = 6'b010000,
    MFLO    = 6'b010010,
    MTHI    = 6'b010001,
    MTLO    = 6'b010011
} func_enum;

/*********************REG****************/
typedef enum logic [4 : 0] {
    REG_ZERO, REG_AT,       // 0 1
    REG_V0, REG_V1,         // 2 3
    REG_A0, REG_A1, REG_A2, REG_A3, //4 5 6 7 
    REG_T0, REG_T1, REG_T2, REG_T3, REG_T4, REG_T5, REG_T6, REG_T7, //8 9 10 11 12 13 14 15
    REG_S0, REG_S1, REG_S2, REG_S3, REG_S4, REG_S5,REG_S6, REG_S7,  //16 17 18 19 20 21 22 23
    REG_T8, REG_T9,  //24 25
    REG_K0, REG_K1, //26 27
    REG_GP, REG_SP, REG_FP, REG_RA  //28 29 30 31
} reg_enum;

/*****************CP0_REG******************/
typedef enum logic [4 : 0] { 
      INDEX, RANDOM, ENTRYLO0, ENTRYLO1, CONTEXT,
      PAGEMASK, WIRED, HWRENA, BADVADDR, COUNT,
      ENTRYHI, COMPARE, STATUS, CAUSE, EPC,
      PRID, CONFIG, LLADDR, WATCHLO, WATCHHI,
      R20, R21, R22, DEBUG, DEPC,
      PERFCNT, ERRCTL, CACHEERR, TAGLO, TAGHI,
      ERROREPC, DESAVE
} cp0_reg_enum;

/**************ALUTPYE**************/
typedef enum logic[2:0] { 
      	ARITH     = 3'b001,       
      	LOGIC     = 3'b010,       
      	SHIFT     = 3'b100,       
      	BRANCH    = 3'b101,       
      	MOVE      = 3'b011,       
	    ZERO      = 3'b000
      	//TRAP      = 3'b110,     
      	//PRV       = 3'b111      
      } alutype_enum;


/******************ALUOP**************/
typedef enum logic[7:0] { 
    aluop_ADD     = 8'h11,
    aluop_ADDI    = 8'h13,
    aluop_ADDU    = 8'h12,
    aluop_ADDIU   = 8'h16,
    //
    aluop_SUB     = 8'h21,
    aluop_SUBU    = 8'h23,
    //
    aluop_SLT     = 8'h31,
    aluop_SLTI    = 8'h33,
    //
    aluop_SLTU    = 8'h42,
    aluop_SLTIU   = 8'h46,
    //
    aluop_DIV     = 8'h81,
    aluop_DIVU    = 8'h83,
    //
    aluop_MULT    = 8'h82,
    aluop_MULTU   = 8'h86,
    aluop_MUL     = 8'h87,
    //
    aluop_AND     = 8'h51,
    aluop_ANDI    = 8'h53,
    //
    aluop_NOR     = 8'h62,
    //
    aluop_OR      = 8'h61,
    aluop_ORI     = 8'h63,
    //
    aluop_XOR     = 8'h71,
    aluop_XORI    = 8'h73,
    //
    aluop_LUI     = 8'h01,
    aluop_SLLV    = 8'h03,
    aluop_SLL     = 8'h02,
    aluop_SRAV    = 8'h06,
    aluop_SRA     = 8'h07,
    aluop_SRLV    = 8'h05,
    aluop_SRL     = 8'h04,
    //
    aluop_BEQ     = 8'hb1,
    aluop_BNE     = 8'hb3,
    aluop_BGEZ    = 8'hb2,
    aluop_BGTZ    = 8'hb6,
    aluop_BLEZ    = 8'hb7,
    aluop_BLTZ    = 8'hb5,
    aluop_BGEZAL  = 8'hb4,
    aluop_BLTZAL  = 8'hbc,
    //
    aluop_J       = 8'hc1,
    aluop_JAL     = 8'hc3,
    aluop_JR      = 8'hc2,
    aluop_JALR    = 8'hc6,
    //
    aluop_MFHI    = 8'hd1,
    aluop_MFLO    = 8'hd3,
    aluop_MTHI    = 8'hd2,
    aluop_MTLO    = 8'hd6,
    aluop_MTC0    = 8'hd7,
    aluop_MFC0    = 8'hd5,
    //
    aluop_LB      = 8'h91,
    aluop_LBU     = 8'h93,
    aluop_LH      = 8'h92,
    aluop_LHU     = 8'h96,
    aluop_LW      = 8'h97,
    //
    aluop_SB      = 8'ha1,
    aluop_SH      = 8'ha3,
    aluop_SW      = 8'ha2,
    //
    aluop_LWL     = 8'h9f,
    aluop_LWR     = 8'h9e,
    aluop_SWL     = 8'ha6,
    aluop_SWR     = 8'ha7,
    //clo
    aluop_CLO     = 8'h17,  //0001 0111,0124
    aluop_CLZ     = 8'h18,  //0001 1000,34

    aluop_ZERO    = 8'h00
 } aluop_enum;

typedef enum logic[4:0] {
    exccode_NONE   = 5'b11111,
    exccode_INT    = 5'b00000,
    exccode_MOD    = 5'b00001,
    exccode_TLBL   = 5'b00010,
    exccode_TLBS   = 5'b00011,
    exccode_ADEL   = 5'b00100,
    exccode_ADES   = 5'b00101,
    exccode_IBS    = 5'b00110,
    exccode_DBE    = 5'b00111,
    exccode_SYS    = 5'b01000,
    exccode_BP     = 5'b01001,
    exccode_RI     = 5'b01010,
    exccode_CPU    = 5'b01011,
    exccode_OV     = 5'b01100,
    exccode_TR     = 5'b01101,
    exccode_WATCH  = 5'b10111,
    exccode_MCHECK = 5'b11000,
    exccode_ERET   = 5'b11001
} exccode_enum; 

typedef enum logic[5:0] { 
    tlbtype_TLBP  = 6'b001000,
    tlbtype_TLBR  = 6'b000001,
    tlbtype_TLBWI = 6'b000010,
    tlbtype_TLBWR = 6'b000110
} tlbtype_enum;

/*********************************/
typedef struct packed{
    opcode_enum op;         //[31:26]  
    reg_enum rs;            //[25:21]
    reg_enum rt;            //[20:16]
    logic [15 : 0] imm;     //[15: 0]      
} inst_i_t;
    
/*********************************/
typedef struct packed{
    opcode_enum op;         //[31:26]      
    reg_enum rs;            //[25:21]  
    reg_enum rt;            //[20:16]  
    reg_enum rd;            //[15:11]  
    logic [4 : 0] sa;       //[10: 6]      
    func_enum func;         //[5 : 0]    
} inst_r_t;
    
/*********************************/
typedef struct packed{
    opcode_enum op;         //[31:26]
    logic [25 : 0] index;   //[25: 0]   
} inst_j_t;
    
/*********************************/
typedef struct packed{
    opcode_enum op;           //[31:26]
    logic [25 : 21] f_or_t;   //[25:21]
    reg_enum rt;              //[20:16]
    cp0_reg_enum rd;            //[15:11]
    logic [10 : 0] constcp0;  //[10:0]
} inst_cp0_t;

/*****************TLB-inst****************/
typedef struct packed {
    opcode_enum op;
    logic co;
    logic [18:0] zero_domain;
    tlbtype_enum tlbtype;
} inst_tlb_t;

typedef union packed{
    inst_i_t i;
    inst_r_t r;
    inst_j_t j;
    inst_cp0_t cp_0;
    inst_tlb_t tlb;        
} inst_t; 
`endif