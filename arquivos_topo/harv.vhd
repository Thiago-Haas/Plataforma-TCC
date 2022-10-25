library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.harv_pkg.all;

entity harv is
  generic (
    PROGRAM_START_ADDR : std_logic_vector(31 downto 0) := x"00000000";
    TMR_CONTROL : boolean := FALSE;
    TMR_ALU     : boolean := FALSE;
    ECC_REGFILE : boolean := FALSE;
    ECC_PC      : boolean := FALSE
  );
  port (
    -- syncronization
    rstn_i  : in std_logic;
    clk_i   : in std_logic;
    start_i : in std_logic;
    -- reset cause
    poweron_rstn_i : in std_logic;
    wdt_rstn_i     : in std_logic;
    -- INSTRUCTION MEMORY
    imem_rden_o  : out std_logic;
    imem_gnt_i   : in  std_logic;
    imem_err_i   : in  std_logic;
    imem_addr_o  : out std_logic_vector(31 downto 0);
    imem_rdata_i : in  std_logic_vector(31 downto 0);
    -- DATA MEMORY
    dmem_wren_o  : out std_logic;
    dmem_rden_o  : out std_logic;
    dmem_gnt_i   : in  std_logic;
    dmem_err_i   : in  std_logic;
    dmem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_wdata_o : out std_logic_vector(31 downto 0);
    dmem_wstrb_o : out std_logic_vector(3 downto 0);
    dmem_rdata_i : in  std_logic_vector(31 downto 0);
    -- interrupt signals
    ext_interrupt_i  : in std_logic_vector(7 downto 0);
    hard_dmem_o      : out std_logic;
    clr_ext_event_o  : out std_logic;
    ext_event_i      : in std_logic;
    periph_timeout_i : in std_logic
  );
end entity;

architecture arch of harv is

  ---------Instruction Fetch ---------
  signal if_pc_w         : std_logic_vector(31 downto 0);
  signal if_pc_4_w       : std_logic_vector(31 downto 0);
  signal ctl_update_pc_w : std_logic;
  -------- Instruction Decode --------
  signal opcode_w     : std_logic_vector( 6 downto 0);
  signal funct3_w     : std_logic_vector( 2 downto 0);
  signal funct7_w     : std_logic_vector( 6 downto 0);
  signal funct12_w    : std_logic_vector(11 downto 0);
  signal rd_w         : std_logic_vector( 4 downto 0);
  signal rs1_w        : std_logic_vector( 4 downto 0);
  signal rs2_w        : std_logic_vector( 4 downto 0);
  signal imm_branch_w : std_logic_vector(12 downto 0);
  signal imm_i_w      : std_logic_vector(11 downto 0);
  -- Immediate value
  signal imm_w     : std_logic_vector(31 downto 0);
  -------------- CONTROL -------------
  signal ctl_handle_trap_w    : std_logic;
  signal ctl_aluop_w          : std_logic_vector(ALUOP_SIZE-1 downto 0);
  signal ctl_alusrc_imm_w     : std_logic;
  signal ctl_imm_shamt_w      : std_logic;
  signal ctl_imm_up_w         : std_logic;
  signal ctl_rd_rs1_w         : std_logic;
  signal ctl_rd_rs2_w         : std_logic;
  signal ctl_regwr_w          : std_logic;
  signal ctl_inv_branch_w     : std_logic;
  signal ctl_branch_w         : std_logic;
  signal ctl_jump_w           : std_logic;
  signal ctl_jalr_w           : std_logic;
  signal ctl_ecall_w          : std_logic;
  signal ctl_ebreak_w         : std_logic;
  signal ctl_mret_w           : std_logic;
  signal ctl_wfi_w            : std_logic;
  signal ctl_mem_rd_w         : std_logic;
  signal ctl_mem_wr_w         : std_logic;
  signal ctl_mem_ben_w        : std_logic_vector(1 downto 0);
  signal ctl_mem_wstrb_w      : std_logic_vector(3 downto 0);
  signal ctl_mem_usgn_w       : std_logic;
  signal ctl_load_upimm_w     : std_logic;
  signal ctl_auipc_w          : std_logic;
  signal ctl_csr_access_w     : std_logic;
  signal ctl_csr_wren_w       : std_logic;
  signal ctl_csr_source_imm_w : std_logic;
  signal ctl_csr_maskop_w     : std_logic;
  signal ctl_csr_clearop_w    : std_logic;
  signal ctl_imem_req_w       : std_logic;
  signal ctl_dmem_req_w       : std_logic;
  signal if_instr_w           : std_logic_vector(31 downto 0);
  -------------- REGFILE --------------
  signal data_wr_w   : std_logic_vector(31 downto 0);
  signal reg_data1_w : std_logic_vector(31 downto 0);
  signal reg_data2_w : std_logic_vector(31 downto 0);
  ---------------- ALU ----------------
  signal alu_data1_w  : std_logic_vector(31 downto 0);
  signal alu_data2_w  : std_logic_vector(31 downto 0);
  signal alu_zero_w   : std_logic;
  signal alu_result_w : std_logic_vector(31 downto 0);
  ------------ TRAP handler -----------
  signal tpe_reg_trap_data_w  : std_logic;
  signal tpe_reg_trap_mepc_w  : std_logic;
  signal tpe_trap_w           : std_logic;
  signal tpe_custom_ip_w      : std_logic_vector(15 downto 0);
  signal tpe_msip_w           : std_logic;
  signal tpe_mtip_w           : std_logic;
  signal tpe_meip_w           : std_logic;
  signal tpe_mscratch_w       : std_logic_vector(31 downto 0);
  signal tpe_mepc_w           : std_logic_vector(31 downto 0);
  signal tpe_mcause_w         : std_logic_vector(31 downto 0);
  signal tpe_mtval_w          : std_logic_vector(31 downto 0);
  signal tpe_mtinst_w         : std_logic_vector(31 downto 0);
  signal tpe_mtval2_w         : std_logic_vector(31 downto 0);
  ---------------- CSR ----------------
  signal csr_rdata_w   : std_logic_vector(31 downto 0);
  signal csr_mepc_w    : std_logic_vector(31 downto 0);
  signal csr_mcycle_w  : std_logic_vector(31 downto 0);
  signal csr_mcycleh_w : std_logic_vector(31 downto 0);
  -- signals for mtime interrupt compare
  signal csr_mtime_w     : std_logic_vector(31 downto 0);
  signal csr_mtimecmp0_w : std_logic_vector(31 downto 0);
  signal csr_mtimecmp1_w : std_logic_vector(31 downto 0);
  -- hardening configuration
  signal csr_hard_pc_w      : std_logic;
  signal csr_hard_regfile_w : std_logic;
  signal csr_hard_control_w : std_logic;
  signal csr_hard_alu_w     : std_logic;
  -- trap setup
  signal csr_mie_w              : std_logic;
  signal csr_mpie_w             : std_logic;
  signal csr_mpp_w              : std_logic_vector(1 downto 0);
  signal csr_trap_base_addr_w   : std_logic_vector(31 downto 0);
  signal csr_trap_vector_mode_w : std_logic;
  signal csr_trap_cause_w       : std_logic_vector(31 downto 0);
  signal csr_custom_ie_w        : std_logic_vector(15 downto 0);
  signal csr_msie_w             : std_logic;
  signal csr_mtie_w             : std_logic;
  signal csr_meie_w             : std_logic;

  -- Memory access
  signal dmem_gnt_w   : std_logic;
  signal dmem_err_w   : std_logic;
  signal dmem_rdata_w : std_logic_vector(31 downto 0);

  -- Event handler
  signal eh_wren_w  : std_logic;
  signal eh_addr_w  : std_logic_vector(11 downto 0);
  signal eh_wdata_w : std_logic_vector(31 downto 0);
  signal eh_rdata_w : std_logic_vector(31 downto 0);
  signal eh_trap_w  : std_logic;

  ----------- events wires -------------
  -- from instruction fetch
  signal if_enc_pc_w : std_logic_vector(38 downto 0);
  signal if_pc_sbu_w : std_logic;
  signal if_pc_dbu_w : std_logic;
  signal if_enc_ir_w : std_logic_vector(38 downto 0);
  signal if_ir_sbu_w : std_logic;
  signal if_ir_dbu_w : std_logic;
  -- from register file
  signal rf_reg1_sbu_w : std_logic;
  signal rf_reg1_dbu_w : std_logic;
  signal rf_enc_data1_w : std_logic_vector(38 downto 0);
  signal rf_reg2_sbu_w : std_logic;
  signal rf_reg2_dbu_w : std_logic;
  signal rf_enc_data2_w : std_logic_vector(38 downto 0);
  -- from control
  signal ctl_err_w : std_logic;
  -- from ALU
  signal alu_err_w : std_logic;
begin

  instr_fetch_u : instr_fetch
  generic map (
    PROGRAM_START_ADDR => PROGRAM_START_ADDR,
    ECC_PC             => ECC_PC
  )
  port map (
    branch_imm_i       => imm_branch_w,
    jump_imm_i         => alu_result_w,
    inv_branch_i       => ctl_inv_branch_w,
    branch_i           => ctl_branch_w,
    zero_i             => alu_zero_w,
    jump_i             => ctl_jump_w,
    correct_error_i    => csr_hard_pc_w,
    instr_gnt_i        => imem_gnt_i,
    instr_i            => imem_rdata_i,
    rstn_i             => rstn_i,
    clk_i              => clk_i,
    update_pc_i        => ctl_update_pc_w,
    handle_trap_i      => ctl_handle_trap_w,
    trap_base_addr_i   => csr_trap_base_addr_w,
    trap_vector_mode_i => csr_trap_vector_mode_w,
    trap_cause_i       => csr_trap_cause_w,
    mret_i             => ctl_mret_w,
    mepc_i             => csr_mepc_w,
    instr_o            => if_instr_w,
    pc_o               => if_pc_w,
    pc_4_o             => if_pc_4_w,
    enc_pc_o           => if_enc_pc_w,
    pc_sbu_o           => if_pc_sbu_w,
    pc_dbu_o           => if_pc_dbu_w,
    enc_ir_o           => if_enc_ir_w,
    ir_sbu_o           => if_ir_sbu_w,
    ir_dbu_o           => if_ir_dbu_w
  );

  opcode_w     <= if_instr_w( 6 downto  0);
  funct3_w     <= if_instr_w(14 downto 12);
  funct7_w     <= if_instr_w(31 downto 25);
  funct12_w    <= if_instr_w(31 downto 20);
  rd_w         <= if_instr_w(11 downto  7);
  rs1_w        <= if_instr_w(19 downto 15);
  rs2_w        <= if_instr_w(24 downto 20);
  imm_branch_w <= if_instr_w(31) & if_instr_w(7) & if_instr_w(30 downto 25) & if_instr_w(11 downto 8) & '0';
  imm_i_w      <= if_instr_w(31 downto 20);

  gen_ft_control : if TMR_CONTROL generate
    control_u : control_tmr
    port map (
      start_i          => start_i,
      imem_gnt_i       => imem_gnt_i,
      imem_err_i       => imem_err_i,
      dmem_gnt_i       => dmem_gnt_w,
      dmem_err_i       => dmem_err_w,
      opcode_i         => opcode_w,
      funct3_i         => funct3_w,
      funct7_i         => funct7_w,
      funct12_i        => funct12_w,
      trap_i           => tpe_trap_w,
      handle_trap_o    => ctl_handle_trap_w,
      rstn_i           => rstn_i,
      clk_i            => clk_i,
      imem_req_o       => ctl_imem_req_w,
      dmem_req_o       => ctl_dmem_req_w,
      update_pc_o      => ctl_update_pc_w,
      aluop_o          => ctl_aluop_w,
      alusrc_imm_o     => ctl_alusrc_imm_w,
      imm_shamt_o      => ctl_imm_shamt_w,
      imm_up_o         => ctl_imm_up_w,
      rd_rs1_o         => ctl_rd_rs1_w,
      rd_rs2_o         => ctl_rd_rs2_w,
      regwr_o          => ctl_regwr_w,
      inv_branch_o     => ctl_inv_branch_w,
      branch_o         => ctl_branch_w,
      jump_o           => ctl_jump_w,
      jalr_o           => ctl_jalr_w,
      ecall_o          => ctl_ecall_w,
      ebreak_o         => ctl_ebreak_w,
      mret_o           => ctl_mret_w,
      wfi_o            => ctl_wfi_w,
      mem_rd_o         => ctl_mem_rd_w,
      mem_wr_o         => ctl_mem_wr_w,
      mem_ben_o        => ctl_mem_ben_w,
      mem_wstrb_o      => ctl_mem_wstrb_w,
      mem_usgn_o       => ctl_mem_usgn_w,
      load_upimm_o     => ctl_load_upimm_w,
      auipc_o          => ctl_auipc_w,
      csr_access_o     => ctl_csr_access_w,
      csr_wren_o       => ctl_csr_wren_w,
      csr_source_imm_o => ctl_csr_source_imm_w,
      csr_maskop_o     => ctl_csr_maskop_w,
      csr_clearop_o    => ctl_csr_clearop_w,
      correct_error_i  => csr_hard_control_w,
      error_o          => ctl_err_w
    );
  end generate;
  gen_normal_control : if not TMR_CONTROL generate
    control_u : control
    port map (
      -- processor status
      start_i    => start_i,
      imem_gnt_i => imem_gnt_i,
      imem_err_i => imem_err_i,
      dmem_gnt_i => dmem_gnt_w,
      dmem_err_i => dmem_err_w,

      -- instruction decode
      opcode_i  => opcode_w,
      funct3_i  => funct3_w,
      funct7_i  => funct7_w,
      funct12_i => funct12_w,

      trap_i        => tpe_trap_w,
      handle_trap_o => ctl_handle_trap_w,

      rstn_i => rstn_i,
      clk_i  => clk_i,

      -- processor status
      set_proc_status_i  => '0',
      next_proc_status_i => (others => '0'),
      next_proc_status_o => open,

      imem_req_o  => ctl_imem_req_w,
      dmem_req_o  => ctl_dmem_req_w,
      update_pc_o => ctl_update_pc_w,

      -- instruction decode
      aluop_o          => ctl_aluop_w,
      alusrc_imm_o     => ctl_alusrc_imm_w,
      imm_shamt_o      => ctl_imm_shamt_w,
      imm_up_o         => ctl_imm_up_w,
      rd_rs1_o         => ctl_rd_rs1_w,
      rd_rs2_o         => ctl_rd_rs2_w,
      regwr_o          => ctl_regwr_w,
      inv_branch_o     => ctl_inv_branch_w,
      branch_o         => ctl_branch_w,
      jump_o           => ctl_jump_w,
      jalr_o           => ctl_jalr_w,
      ecall_o          => ctl_ecall_w,
      ebreak_o         => ctl_ebreak_w,
      mret_o           => ctl_mret_w,
      wfi_o            => ctl_wfi_w,
      mem_rd_o         => ctl_mem_rd_w,
      mem_wr_o         => ctl_mem_wr_w,
      mem_ben_o        => ctl_mem_ben_w,
      mem_wstrb_o      => ctl_mem_wstrb_w,
      mem_usgn_o       => ctl_mem_usgn_w,
      load_upimm_o     => ctl_load_upimm_w,
      auipc_o          => ctl_auipc_w,
      csr_access_o     => ctl_csr_access_w,
      csr_wren_o       => ctl_csr_wren_w,
      csr_source_imm_o => ctl_csr_source_imm_w,
      csr_maskop_o     => ctl_csr_maskop_w,
      csr_clearop_o    => ctl_csr_clearop_w
    );
    ctl_err_w <= '0';
  end generate;

  regfile_wdata_selector_u : regfile_wdata_selector
  port map (
    -- control
    ctl_mem_rd_i     => ctl_mem_rd_w,
    ctl_load_upimm_i => ctl_load_upimm_w,
    ctl_jump_i       => ctl_jump_w,
    ctl_csr_access_i => ctl_csr_access_w,
    -- datapath
    dmem_rdata_i     => dmem_rdata_w,
    imm_i            => imm_w,
    if_pc_4_i        => if_pc_4_w,
    csr_rdata_i      => csr_rdata_w,
    alu_result_i     => alu_result_w,
    regfile_wdata_o  => data_wr_w
  );

  regfile_u : regfile
  generic map (
    ECC_ENABLE => ECC_REGFILE
  )
  port map (
    data_i       => data_wr_w,
    wren_i       => ctl_regwr_w,
    rd_i         => rd_w,
    rs1_i        => rs1_w,
    rs2_i        => rs2_w,
    correct_en_i => csr_hard_regfile_w,
    rstn_i       => rstn_i,
    clk_i        => clk_i,
    sbu1_o       => rf_reg1_sbu_w,
    dbu1_o       => rf_reg1_dbu_w,
    data1_o      => reg_data1_w,
    sbu2_o       => rf_reg2_sbu_w,
    dbu2_o       => rf_reg2_dbu_w,
    data2_o      => reg_data2_w,
    enc_data1_o  => rf_enc_data1_w,
    enc_data2_o  => rf_enc_data2_w
  );

  immediate_selector_u : immediate_selector
  port map (
    ctl_imm_shamt_i => ctl_imm_shamt_w,
    ctl_imm_up_i    => ctl_imm_up_w,
    ctl_mem_wr_i    => ctl_mem_wr_w,
    ctl_jump_i      => ctl_jump_w,
    ctl_jalr_i      => ctl_jalr_w,
    instr_i         => if_instr_w,
    immediate_o     => imm_w
  );

  alu_data_selector_u : alu_data_selector
  port map (
    ctl_auipc_i      => ctl_auipc_w,
    ctl_jump_i       => ctl_jump_w,
    ctl_jalr_i       => ctl_jalr_w,
    ctl_alusrc_imm_i => ctl_alusrc_imm_w,
    if_pc_i          => if_pc_w,
    imm_i            => imm_w,
    reg_data1_i      => reg_data1_w,
    reg_data2_i      => reg_data2_w,
    alu_data1_o      => alu_data1_w,
    alu_data2_o      => alu_data2_w
  );

  gen_ft_alu : if TMR_ALU generate
    alu_u : alu_tmr
    port map (
      data1_i         => alu_data1_w,
      data2_i         => alu_data2_w,
      operation_i     => ctl_aluop_w,
      zero_o          => alu_zero_w,
      result_o        => alu_result_w,
      correct_error_i => csr_hard_alu_w,
      error_o         => alu_err_w
    );
  end generate;
  gen_normal_alu : if not TMR_ALU generate
    alu_u : alu
    port map (
      data1_i     => alu_data1_w,
      data2_i     => alu_data2_w,
      operation_i => ctl_aluop_w,
      zero_o      => alu_zero_w,
      result_o    => alu_result_w
    );
    alu_err_w <= '0';
  end generate;

  -- Trap encoder
  trap_encoder_u : trap_encoder
  port map (
    clk_i  => clk_i,
    rstn_i => rstn_i,
    -- setup
    mie_i       => csr_mie_w,
    mpie_i      => csr_mpie_w,
    mpp_i       => csr_mpp_w,
    custom_ie_i => csr_custom_ie_w,
    msie_i      => csr_msie_w,
    mtie_i      => csr_mtie_w,
    meie_i      => csr_meie_w,
    -- handler
    handle_trap_i   => ctl_handle_trap_w,
    pc_i            => if_pc_w,
    instr_i         => if_instr_w,
    reg_trap_data_o => tpe_reg_trap_data_w,
    reg_trap_mepc_o => tpe_reg_trap_mepc_w,
    trap_o          => tpe_trap_w,
    custom_ip_o     => tpe_custom_ip_w,
    msip_o          => tpe_msip_w,
    mtip_o          => tpe_mtip_w,
    meip_o          => tpe_meip_w,
    mscratch_o      => tpe_mscratch_w,
    mepc_o          => tpe_mepc_w,
    mcause_o        => tpe_mcause_w,
    mtval_o         => tpe_mtval_w,
    mtinst_o        => tpe_mtinst_w,
    mtval2_o        => tpe_mtval2_w,
    -- trap signals
    ecall_i              => ctl_ecall_w,
    load_access_fault_i  => (dmem_err_w and ctl_dmem_req_w and ctl_mem_rd_w) or (imem_err_i and ctl_imem_req_w),
    store_access_fault_i => dmem_err_w and ctl_dmem_req_w and ctl_mem_wr_w,
    eh_trap_i            => eh_trap_w,
    mtime_i              => csr_mtime_w,
    mtimecmp0_i          => csr_mtimecmp0_w,
    mtimecmp1_i          => csr_mtimecmp1_w,
    ext_interrupt_i      => ext_interrupt_i
  );

  ---------- CSR registers ---------
  csr_u : csr
  generic map (
    TMR_CONTROL => TMR_CONTROL,
    TMR_ALU     => TMR_ALU,
    ECC_REGFILE => ECC_REGFILE,
    ECC_PC      => ECC_PC
  )
  port map (
    -- sync
    rstn_i => rstn_i,
    clk_i  => clk_i,
    -- access interface
    addr_i     => imm_i_w,
    data_o     => csr_rdata_w,
    rs1_data_i => reg_data1_w,
    imm_data_i => rs1_w,
    -- write control
    wren_i        => ctl_csr_wren_w,
    source_imm_i  => ctl_csr_source_imm_w,
    csr_maskop_i  => ctl_csr_maskop_w,
    csr_clearop_i => ctl_csr_clearop_w,
    -- registers
    mepc_o    => csr_mepc_w,
    mcycle_o  => csr_mcycle_w,
    mcycleh_o => csr_mcycleh_w,
    -- trap setup
    mie_o              => csr_mie_w,
    mpie_o             => csr_mpie_w,
    mpp_o              => csr_mpp_w,
    trap_base_addr_o   => csr_trap_base_addr_w,
    trap_vector_mode_o => csr_trap_vector_mode_w,
    trap_cause_o       => csr_trap_cause_w,
    custom_ie_o        => csr_custom_ie_w,
    msie_o             => csr_msie_w,
    mtie_o             => csr_mtie_w,
    meie_o             => csr_meie_w,
    -- trap handling
    reg_trap_i      => tpe_reg_trap_data_w,
    reg_trap_mepc_i => tpe_reg_trap_mepc_w,
    custom_ip_i     => tpe_custom_ip_w,
    msip_i          => tpe_msip_w,
    mtip_i          => tpe_mtip_w,
    meip_i          => tpe_meip_w,
    mscratch_i      => tpe_mscratch_w,
    mepc_i          => tpe_mepc_w,
    mcause_i        => tpe_mcause_w,
    mtval_i         => tpe_mtval_w,
    mtinst_i        => tpe_mtinst_w,
    mtval2_i        => tpe_mtval2_w,
    -- signals for mtime interrupt
    mtime_o     => csr_mtime_w,
    mtimecmp0_o => csr_mtimecmp0_w,
    mtimecmp1_o => csr_mtimecmp1_w,
    -- hardening
    hard_pc_o      => csr_hard_pc_w,
    hard_regfile_o => csr_hard_regfile_w,
    hard_control_o => csr_hard_control_w,
    hard_alu_o     => csr_hard_alu_w,
    -- resets
    poweron_rstn_i => poweron_rstn_i,
    wdt_rstn_i     => wdt_rstn_i
  );

  -------- INSTRUCTION MEMORY ---------
  imem_rden_o <= ctl_imem_req_w;
  imem_addr_o <= if_pc_w;

  -------- DATA MEMORY --------
  mem_interface_u : mem_interface
  port map (
    -- control signals
    ctl_dmem_req_i  => ctl_dmem_req_w,
    ctl_mem_wr_i    => ctl_mem_wr_w,
    ctl_mem_ben_i   => ctl_mem_ben_w,
    ctl_mem_wstrb_i => ctl_mem_wstrb_w,
    ctl_mem_usgn_i  => ctl_mem_usgn_w,
    -- datapath signals
    alu_result_i    => alu_result_w,
    reg_data2_i     => reg_data2_w,
    -- interface
    mem_gnt_o       => dmem_gnt_w,
    mem_err_o       => dmem_err_w,
    mem_rdata_o     => dmem_rdata_w,
    -- dmem output
    dmem_wren_o     => dmem_wren_o,
    dmem_rden_o     => dmem_rden_o,
    dmem_gnt_i      => dmem_gnt_i,
    dmem_err_i      => dmem_err_i,
    dmem_addr_o     => dmem_addr_o,
    dmem_wdata_o    => dmem_wdata_o,
    dmem_wstrb_o    => dmem_wstrb_o,
    dmem_rdata_i    => dmem_rdata_i,
    -- local mm reg eh
    eh_wren_o       => eh_wren_w,
    eh_addr_o       => eh_addr_w,
    eh_wdata_o      => eh_wdata_w,
    eh_rdata_i      => eh_rdata_w
  );

  -------- Memory-Mapped event handler --------
  -- output signals
  event_handler_u : event_handler
  port map (
    rstn_i => rstn_i,
    clk_i  => clk_i,
    -- local interface
    wren_i  => eh_wren_w,
    addr_i  => eh_addr_w,
    wdata_i => eh_wdata_w,
    rdata_o => eh_rdata_w,
    -- event information
    -- pc
    pc_sbu_i      => if_pc_sbu_w,
    pc_dbu_i      => if_pc_dbu_w,
    pc_enc_data_i => if_enc_pc_w,
    -- ir
    ir_sbu_i      => if_ir_sbu_w,
    ir_dbu_i      => if_ir_dbu_w,
    ir_enc_data_i => if_enc_ir_w,
    -- rs1
    regfile_rd_rs1_i    => ctl_rd_rs1_w,
    regfile_rs1_i       => rs1_w,
    regfile_reg1_sbu_i  => rf_reg1_sbu_w,
    regfile_reg1_dbu_i  => rf_reg1_dbu_w,
    regfile_enc_data1_i => rf_enc_data1_w,
    -- rs2
    regfile_rd_rs2_i    => ctl_rd_rs2_w,
    regfile_rs2_i       => rs2_w,
    regfile_reg2_sbu_i  => rf_reg2_sbu_w,
    regfile_reg2_dbu_i  => rf_reg2_dbu_w,
    regfile_enc_data2_i => rf_enc_data2_w,
    -- ctl
    ctl_err_i => ctl_err_w,
    -- alu
    alu_err_i => alu_err_w,
    -- external
    ext_event_i      => ext_event_i,
    periph_timeout_i => periph_timeout_i,
    -- additional
    instr_i      => if_instr_w,
    alu_result_i => alu_result_w,
    mcycle_i     => csr_mcycle_w,
    mcycleh_i    => csr_mcycleh_w,
    jump_i       => ctl_jump_w,
    jalr_i       => ctl_jalr_w,
    dmem_req_i   => ctl_dmem_req_w,
    update_pc_i  => ctl_update_pc_w,
    regfile_rd_i => rd_w,
    pc_i         => if_pc_w,
    -- trap flag
    trap_o => eh_trap_w
  );

end architecture;
