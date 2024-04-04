`ifndef TLB_DEFS_SVH
`define TLB_DEFS_SVH
parameter TLBNUM = 32;
//CP0_REGS DOMAIN
//Index domain
parameter INDEX_WIDTH = 5;
parameter INDEX_P = 31;
//Cacheability
parameter CACHED = 3'd3;
parameter UNCACHED = 3'd2; 
//
//
parameter TLB_REFILL_BADADDR = 32'hbfc00200;
//
parameter BADVPN2_HIGH = 22;
parameter BADVPN2_LOW  = 4;

typedef struct packed {
    logic [18:0] vpn;
    logic        odd;
    logic [11:0] offset;
} tlb_vaddr;

typedef struct packed {
    logic [19:0] pfn;
    logic [11:0] offset;
} tlb_paddr;

typedef struct packed {
    logic [18:0] vpn2;      //19
    logic [4:0]  zero_do;   //5
    logic [7:0]  asid;      //8
} tlb_entryhi;              //total 32

typedef struct packed {
    logic [5:0]  zero_do;   //6
    logic [19:0] pfn;       //20
    logic [2:0]  c;         //3
    logic        d;
    logic        v;
    logic        g;         //3
} tlb_entrylo;              //total 32

typedef struct packed {
    tlb_entryhi    entryhi;
    tlb_entrylo    entrylo0;
    tlb_entrylo    entrylo1;
    //logic [31:0]    index;
    //logic [31:0]    pagemask;
    //logic [31:0]    random;
    //logic [31:0]    Context;
    //logic [31:0]    wired;
} tlb_wr;

/* typedef struct packed {
    logic [31:0]    entryhi;
    logic [31:0]    entrylo0;
    logic [31:0]    entrylo1;
    logic [31:0]    p_index;
    //logic [31:0]    pagemask;
    //logic [31:0]    random;
    //logic [31:0]    Context;
    //logic [31:0]    wired;
} tlb_rap; //read & probe
 */
typedef struct packed {
    //logic [1:0] kseg;
    logic      mapped;
    logic      cached;
    logic      uncached;
} tlb_cache;

typedef enum logic[2:0] { 
    TLBEXC_NONE,TLBEXC_REFILL_L,TLBEXC_REFILL_S,TLBEXC_INVALID_L,TLBEXC_INVALID_S,TLBEXC_MOD
} tlb_exc;

typedef struct packed {
    logic match;
    logic valid;
    logic cached;
} itlb_state;

typedef struct packed {
    logic match;
    logic valid;
    logic dirty;
    logic cached;
} dtlb_state;

typedef enum logic[2:0] { 
    NONE,TLBR,TLBWI,TLBWR,TLBP
} tlb_op;
`endif