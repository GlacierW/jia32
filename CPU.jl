include("PhysicalMemory.jl")
include("hw/IODev.jl")

const RAX_type = UInt64; const RAX_seq = 0; 
const EAX_type = UInt32; const EAX_seq = 0;
const AX_type  = UInt16; const AX_seq  = 0;
const AL_type  = UInt8; const AL_seq  = 0;

const RCX_type = UInt64; const RCX_seq = 1; 
const ECX_type = UInt32; const ECX_seq = 1;
const CX_type  = UInt16; const CX_seq  = 1;
const CL_type  = UInt8; const CL_seq  = 1;

const RDX_type = UInt64; const RDX_seq = 2; 
const EDX_type = UInt32; const EDX_seq = 2;
const DX_type  = UInt16; const DX_seq  = 2;
const DL_type  = UInt8; const DL_seq  = 2;

const RBX_type = UInt64; const RBX_seq = 3; 
const EBX_type = UInt32; const EBX_seq = 3;
const BX_type  = UInt16; const BX_seq  = 3;
const BL_type  = UInt8; const BL_seq  = 3;

const RSP_type = UInt64; const RSP_seq = 4; 
const ESP_type = UInt32; const ESP_seq = 4;
const SP_type  = UInt16; const SP_seq  = 4;

const RBP_type = UInt64; const RBP_seq = 5; 
const EBP_type = UInt32; const EBP_seq = 5;
const BP_type  = UInt16; const BP_seq  = 5;

const RSI_type = UInt64; const RSI_seq = 6; 
const ESI_type = UInt32; const ESI_seq = 6;
const SI_type  = UInt16; const SI_seq  = 6;

const RDI_type = UInt64; const RDI_seq = 7; 
const EDI_type = UInt32; const EDI_seq = 7;
const DI_type  = UInt16; const DI_seq  = 7;

const RIP_type = UInt64; const RIP_seq = 16;
const EIP_type = UInt32; const EIP_seq = 16;
const IP_type = UInt16; const IP_seq = 16;

# Vol. 2C, B.1.4.5, Table B-8
const ES = 0
const CS = 1
const SS = 2
const DS = 3
const FS = 4
const GS = 5

const OP_ADD = 0
const OP_ADC = 1
const OP_AND = 2
const OP_XOR = 3
const OP_OR  = 4
const OP_SBB = 5
const OP_SUB = 6
const OP_CMP = 7
const OP_NB  = 8

# CPU (R/E)FLAGS masks
#	Status Flag
const CPU_CF   = UInt64(0b1)
const CPU_PF   = UInt64(0b1) << 2
const CPU_AF   = UInt64(0b1) << 4
const CPU_ZF   = UInt64(0b1) << 6
const CPU_SF   = UInt64(0b1) << 7
const CPU_OF   = UInt64(0b1) << 11

#	Control Flag
const CPU_DF   = UInt64(0x01) << 10

#	System Flag
const CPU_TF   = UInt64(0b1)  << 8
const CPU_IF   = UInt64(0b1)  << 9
const CPU_IOPL = UInt64(0b11) << 12
const CPU_NT   = UInt64(0b1)  << 14
const CPU_RF   = UInt64(0b1)  << 16
const CPU_VM   = UInt64(0b1)  << 17
const CPU_AC   = UInt64(0b1)  << 18
const CPU_VIF  = UInt64(0b1)  << 19
const CPU_VIP  = UInt64(0b1)  << 20
const CPU_ID   = UInt64(0b1)  << 21

#	CR0 Flag
const CR0_PE   = UInt64(0b1)
const CR0_MP   = UInt64(0b1)  << 1
const CR0_EM   = UInt64(0b1)  << 2
const CR0_TS   = UInt64(0b1)  << 3
const CR0_ET   = UInt64(0b1)  << 4
const CR0_NE   = UInt64(0b1)  << 5
const CR0_WP   = UInt64(0b1)  << 16
const CR0_AM   = UInt64(0b1)  << 18
const CR0_NW   = UInt64(0b1)  << 29
const CR0_CD   = UInt64(0b1)  << 30
const CR0_PG   = UInt64(0b1)  << 31

IOFunc = Union(Bool, Function)

type JITBlock
	exec:: Function
	nb_instr:: UInt64
	nb_exec:: UInt64

	function JITBlock(f:: Function, icount:: UInt64)
		block = new(f, icount, 0)
		return block
	end
end

type CPU
	genl_regs_buffer:: Array{UInt8}
	genl_regs:: Ptr{UInt8}
	seg_regs_buffer:: Array{UInt16}
	seg_regs:: Ptr{UInt16}
	rflags:: UInt64
	cr0:: UInt64
	cr1:: UInt64
	cr2:: UInt64
	cr3:: UInt64
	cr4:: UInt64
	cr8:: UInt64

	# Internal use
	seg_regs_base_buffer:: Array{UInt64}
	seg_regs_base:: Ptr{UInt64}

	operand_size:: Int
	address_size:: Int

	decoding_rip:: UInt64
	decoding_eip:: UInt32
	decoding_ip:: UInt16

	emu_insn_tbl:: Dict{UInt32, Function}
	jit_insn_tbl:: Dict{UInt32, Function}

	lazyf_op:: Int
	lazyf_width:: Int
	lazyf_op1:: UInt64
	lazyf_op2:: UInt64

	segment:: Int
	single_stepping:: Bool
	this_instr_len:: UInt8
	ip_addend:: UInt8
	jit_enabled:: Bool
	jit_rip:: UInt64
	jit_eot:: Bool
	jl_blocks:: Dict{UInt64, Dict{UInt64, JITBlock}}

	#= Port I/O system
	   For devices that are accessed through a separated I/O port space.
	   Instruction in, out, ins, outs access through this system.
	   No 64-bit access =#
	#port_iomap:: Array{Bool}
	port_iomap_dev:: Array{IODev}
	port_iomap_r32:: Array{IOFunc}
	port_iomap_r16:: Array{IOFunc}
	port_iomap_r8::  Array{IOFunc}
	port_iomap_w32:: Array{IOFunc}
	port_iomap_w16:: Array{IOFunc}
	port_iomap_w8::  Array{IOFunc}
 
	# Constructor
	function CPU(phys_mem_size:: UInt64)
		cpu = new()

		# 16 64-bit general-purpose registers and instruction pointer
		cpu.genl_regs_buffer = Array(UInt8, 16 * 8 + 8)
		cpu.genl_regs = pointer(cpu.genl_regs_buffer)

		# 6 16-bit segment register and their hidden parts
		cpu.seg_regs_buffer = Array(UInt16, 6)
		cpu.seg_regs = pointer(cpu.seg_regs_buffer)
		cpu.seg_regs_base_buffer = Array(UInt64, 6)
		cpu.seg_regs_base = pointer(cpu.seg_regs_base_buffer)

		cpu.segment = -1
		cpu.operand_size = 16
		cpu.address_size = 16
		cpu.emu_insn_tbl = Dict{UInt32, Function}()
		cpu.jit_insn_tbl = Dict{UInt32, Function}()

		cpu.single_stepping = false
		cpu.jit_enabled = true
		cpu.jl_blocks = Dict{UInt64, Dict{UInt64, JITBlock}}()

		#cpu.port_iomap = Array(Bool, 1 << 16)
		cpu.port_iomap_dev = Array(IODev, 1 << 16)
		cpu.port_iomap_r32 = Array(IOFunc, 1 << 16)
		cpu.port_iomap_r16 = Array(IOFunc, 1 << 16)
		cpu.port_iomap_r8  = Array(IOFunc, 1 << 16)
		cpu.port_iomap_w32 = Array(IOFunc, 1 << 16)
		cpu.port_iomap_w16 = Array(IOFunc, 1 << 16)
		cpu.port_iomap_w8  = Array(IOFunc, 1 << 16)
		fill!(cpu.port_iomap_r32, false)
		fill!(cpu.port_iomap_r16, false)
		fill!(cpu.port_iomap_r8,  false)
		fill!(cpu.port_iomap_w32, false)
		fill!(cpu.port_iomap_w16, false)
		fill!(cpu.port_iomap_w8,  false)

		# rflags lazy-computing init
		cpu.lazyf_op = OP_NB

		return cpu
	end
end

# General register access functions
macro reg_w!(cpu, width, seq, data)
	return :(unsafe_store!(convert(Ptr{$width}, $cpu.genl_regs + $seq * 8), $data, 1))
end

macro reg_w_named!(cpu, reg, data)
	return :(@reg_w!($cpu, $(symbol("$reg" * "_type")), $(symbol("$reg" * "_seq")), $data))
end

macro reg_w64!(cpu, reg, data)
	return :(@reg_w!($cpu, UInt64, $(symbol("$reg" * "_seq")), $data))
end

macro reg_w32!(cpu, reg, data)
	return :(@reg_w!($cpu, UInt32, $(symbol("$reg" * "_seq")), $data))
end

macro reg_w16!(cpu, reg, data)
	return :(@reg_w!($cpu, UInt16, $(symbol("$reg" * "_seq")), $data))
end

macro reg_r(cpu, width, seq)
	return :(unsafe_load(convert(Ptr{$width}, $cpu.genl_regs + $seq * 8), 1))
end

macro reg_r_named(cpu, reg)
	return :(@reg_r($cpu, $(symbol("$reg" * "_type")), $(symbol("$reg" * "_seq"))))
end

macro reg_r64(cpu, reg)
	return :(@reg_r($cpu, UInt64, $(symbol("$reg" * "_seq"))))
end

macro reg_r32(cpu, reg)
	return :(@reg_r($cpu, UInt32, $(symbol("$reg" * "_seq"))))
end

macro reg_r16(cpu, reg)
	return :(@reg_r($cpu, UInt16, $(symbol("$reg" * "_seq"))))
end

# Instruction pointer access function
macro rip(cpu)
	return :(@reg_r_named($cpu, RIP))
end

macro rip!(cpu, data)
	return :(@reg_w_named!($cpu, RIP, $data))
end

macro rip_add!(cpu, addend)
	return :(@rip!($cpu, (@rip($cpu) + $addend) & 0xffffffffffffffff))
end

macro eip(cpu)
	return :(@reg_r_named($cpu, EIP))
end

macro eip!(cpu, data)
	return :(@reg_w_named!($cpu, EIP, $data))
end

macro eip_add!(cpu, addend)
	return :(@eip!($cpu, (@eip($cpu) + $addend) & 0xffffffff))
end

macro ip(cpu)
	return :(@reg_r_named($cpu, IP))
end

macro ip!(cpu, data)
	return :(@reg_w_named!($cpu, IP, $data))
end

macro ip_add!(cpu, addend)
	return :(@ip!($cpu, (@ip($cpu) + $addend) & 0xffff))
end

# Segment register access function
macro sreg!(cpu, seq, data)
	return :(unsafe_store!(convert(Ptr{UInt16}, $cpu.seg_regs + $seq * 2), $data, 1))
end

macro sreg(cpu, seq)
	return :(unsafe_load(convert(Ptr{UInt16}, $cpu.seg_regs + $seq * 2), 1))
end

macro sreg_base!(cpu, seq, data)
	return :(unsafe_store!(convert(Ptr{UInt64}, $cpu.seg_regs_base + $seq * 8), $data, 1))
end

macro sreg_base(cpu, seq)
	return :(unsafe_load(convert(Ptr{UInt64}, $cpu.seg_regs_base + $seq * 8), 1))
end

# Flag register lazy-update function
parity_table = [ 
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x04, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04, 0x00,
	0x00, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00, 0x04,
]:: Array{UInt8, 1}

# The following rflags_compute_XXX function should be called only via rflags_compute!
function rflags_compute_add!(cpu:: CPU, dt:: DataType)
	
	data_max = typemax(dt)
	dst::UInt64 = cpu.lazyf_op1 + cpu.lazyf_op2
	 
	cf::UInt32 = ((dst & data_max) < cpu.lazyf_op1)? 0x1 : 0x0
	pf::UInt32 = parity_table[(dst & 0xff) + 1]
	af::UInt32 = (dst $ cpu.lazyf_op1 $ cpu.lazyf_op2) & 0x10
	zf::UInt32 = ((dst & data_max) == 0x0)? 0x40: 0x0
	sf::UInt32 = (dst >>> abs(8 - cpu.lazyf_width)) & 0x80
	of::UInt32 = ((((cpu.lazyf_op1 $ cpu.lazyf_op2 $ 0xffffffff) & (cpu.lazyf_op1 $ dst)) >>> abs(8 - cpu.lazyf_width)) & 0x80) << 4
	
	# clear & assign the affected flag: Carry, Parity, Adjust, Zero, Sign, Overflow
	cpu.rflags &= ~(CPU_CF | CPU_PF | CPU_AF | CPU_ZF | CPU_SF | CPU_OF)
	cpu.rflags |= (cf | pf | af | zf | sf | of)
end

function rflags_compute_adc!(cpu:: CPU, dt:: DataType)

	data_max = typemax(dt)
	dst::UInt64 = cpu.lazyf_op1 + cpu.lazyf_op2 + 1
	 
	cf::UInt32 = ((dst & data_max) <= cpu.lazyf_op1)? 0x1 : 0x0
	pf::UInt32 = parity_table[(dst & 0xff) + 1]
	af::UInt32 = (dst $ cpu.lazyf_op1 $ cpu.lazyf_op2) & 0x10
	zf::UInt32 = ((dst & data_max) == 0x0)? 0x40: 0x0
	sf::UInt32 = (dst >>> abs(8 - cpu.lazyf_width)) & 0x80
	of::UInt32 = ((((cpu.lazyf_op1 $ cpu.lazyf_op2 $ 0xffffffff) & (cpu.lazyf_op1 $ dst)) >>> abs(8 - cpu.lazyf_width)) & 0x80) << 4
	
	cpu.rflags &= ~(CPU_CF | CPU_PF | CPU_AF | CPU_ZF | CPU_SF | CPU_OF)
	cpu.rflags |= (cf | pf | af | zf | sf | of)
end

function rflags_compute_and!(cpu:: CPU, dt:: DataType)

	data_max = typemax(dt)
	dst::UInt64 = cpu.lazyf_op1 & cpu.lazyf_op2

	cf::UInt32 = 0x0
	pf::UInt32 = parity_table[(dst & 0xff) + 1]
	af::UInt32 = 0x0
	zf::UInt32 = ((dst & data_max) == 0x0)? 0x40: 0x0
	sf::UInt32 = (dst >>> abs(8 - cpu.lazyf_width)) & 0x80
	of::UInt32 = 0x0
	
	cpu.rflags &= ~(CPU_CF | CPU_PF | CPU_AF | CPU_ZF | CPU_SF | CPU_OF)
	cpu.rflags |= (cf | pf | af | zf | sf | of)
end

function rflags_compute_xor!(cpu:: CPU, dt:: DataType)

	data_max = typemax(dt)
	dst::UInt64 = cpu.lazyf_op1 $ cpu.lazyf_op2

	cf::UInt32 = 0x0
	pf::UInt32 = parity_table[(dst & 0xff) + 1]
	af::UInt32 = 0x0
	zf::UInt32 = ((dst & data_max) == 0x0)? 0x40: 0x0
	sf::UInt32 = (dst >>> abs(8 - cpu.lazyf_width)) & 0x80
	of::UInt32 = 0x0
	
	cpu.rflags &= ~(CPU_CF | CPU_PF | CPU_AF | CPU_ZF | CPU_SF | CPU_OF)
	cpu.rflags |= (cf | pf | af | zf | sf | of)
end

function rflags_compute_or!(cpu:: CPU, dt:: DataType)

	data_max = typemax(dt)
	dst::UInt64 = cpu.lazyf_op1 | cpu.lazyf_op2

	cf::UInt32 = 0x0
	pf::UInt32 = parity_table[(dst & 0xff) + 1]
	af::UInt32 = 0x0
	zf::UInt32 = ((dst & data_max) == 0x0)? 0x40: 0x0
	sf::UInt32 = (dst >>> abs(8 - cpu.lazyf_width)) & 0x80
	of::UInt32 = 0x0
	
	cpu.rflags &= ~(CPU_CF | CPU_PF | CPU_AF | CPU_ZF | CPU_SF | CPU_OF)
	cpu.rflags |= (cf | pf | af | zf | sf | of)
end

function rflags_compute_sub!(cpu:: CPU, dt:: DataType)
 
	data_max = typemax(dt)
	dst::UInt64 = cpu.lazyf_op1 - cpu.lazyf_op2
	 
	cf::UInt32 = (cpu.lazyf_op1 < cpu.lazyf_op2)? 0x1 : 0x0
	pf::UInt32 = parity_table[(dst & 0xff) + 1]
	af::UInt32 = (dst $ cpu.lazyf_op1 $ cpu.lazyf_op2) & 0x10
	zf::UInt32 = ((dst & data_max) == 0x0)? 0x40: 0x0
	sf::UInt32 = (dst >>> abs(8 - cpu.lazyf_width)) & 0x80
	of::UInt32 = ((((cpu.lazyf_op1 $ cpu.lazyf_op2) & (cpu.lazyf_op1 $ dst)) >>> abs(8 - cpu.lazyf_width)) & 0x80) << 4
	
	cpu.rflags &= ~(CPU_CF | CPU_PF | CPU_AF | CPU_ZF | CPU_SF | CPU_OF)
	cpu.rflags |= (cf | pf | af | zf | sf | of)
end

function rflags_compute_sbb!(cpu:: CPU, dt:: DataType)

	data_max = typemax(dt)
	dst::UInt64 = cpu.lazyf_op1 - cpu.lazyf_op2 - 1
	 
	cf::UInt32 = (cpu.lazyf_op1 <= cpu.lazyf_op2)? 0x1 : 0x0
	pf::UInt32 = parity_table[(dst & 0xff) + 1]
	af::UInt32 = (dst $ cpu.lazyf_op1 $ cpu.lazyf_op2) & 0x10
	zf::UInt32 = ((dst & data_max) == 0x0)? 0x40: 0x0
	sf::UInt32 = (dst >>> abs(8 - cpu.lazyf_width)) & 0x80
	of::UInt32 = ((((cpu.lazyf_op1 $ cpu.lazyf_op2) & (cpu.lazyf_op1 $ dst)) >>> abs(8 - cpu.lazyf_width)) & 0x80) << 4
	
	cpu.rflags &= ~(CPU_CF | CPU_PF | CPU_AF | CPU_ZF | CPU_SF | CPU_OF)
	cpu.rflags |= (cf | pf | af | zf | sf | of)  
end

rfl_compute_handler = Array(Function, OP_NB)
rfl_compute_dt		= Dict( 8=>UInt8, 16=>UInt16, 32=>UInt32, 64=>UInt64 )

rfl_compute_handler[@ZB(OP_ADD)] = rflags_compute_add!
rfl_compute_handler[@ZB(OP_ADC)] = rflags_compute_adc!
rfl_compute_handler[@ZB(OP_AND)] = rflags_compute_and!
rfl_compute_handler[@ZB(OP_XOR)] = rflags_compute_xor!
rfl_compute_handler[@ZB(OP_OR)]  = rflags_compute_or!
rfl_compute_handler[@ZB(OP_SBB)] = rflags_compute_sbb!
rfl_compute_handler[@ZB(OP_SUB)] = rflags_compute_sub!
rfl_compute_handler[@ZB(OP_CMP)] = rflags_compute_sub!

@noinline function rflags_compute!(cpu:: CPU)
	# perform rflags computation only if the previous operation is recognizable
	if cpu.lazyf_op < OP_NB
		rfl_compute_handler[@ZB(cpu.lazyf_op)](cpu, rfl_compute_dt[cpu.lazyf_width])
	end
	return nothing
end

# MMU functions
# Vol. 1, Chapter 3.3.1 & Fig. 3-3
@noinline function logical_to_physical_real_mode(cpu:: CPU, seg:: Int, offset:: UInt16)
	return UInt64((@sreg_base(cpu, seg) & 0xffffffff) + offset)
end

@noinline function logical_to_physical(cpu:: CPU, seg:: Int, offset:: UInt64)
	if true # Condition to fetch instruction in real mode
		return UInt64(logical_to_physical_real_mode(cpu, seg, UInt16(offset & 0xffff)))
	end
end

# -----64-----
function ru64_crosspg(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	ret = UInt64(0)
	for i = 0 : 7
		ret += (UInt64(phys_read_u8(mem, logical_to_physical(cpu, seg, offset + i))) << (i << 3))
	end
	return ret
end

@noinline function ru64_fast(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	phys_addr = logical_to_physical(cpu, seg, offset)
	return phys_read_u64(mem, phys_addr)
end

function ru64(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	#if ((offset + 7) $ offset) & (~UInt64(0xfff)) == 0
	if (offset & (UInt64(0xfff))) < 4089
		# In the same page
		return ru64_fast(cpu, mem, seg, offset)
	else
		# Cross-page access
		return ru64_crosspg(cpu, mem, seg, offset)
	end
end

@inline function rs64(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	return reinterpret(Int64, ru64(cpu, mem, seg, offset))
end

# -----32-----
function ru32_crosspg(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	ret = UInt32(0)
	for i = 0 : 3
		ret += (UInt32(phys_read_u8(mem, logical_to_physical(cpu, seg, offset + i))) << (i << 3))
	end
	return ret
end

@noinline function ru32_fast(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	phys_addr = logical_to_physical(cpu, seg, offset)
	return phys_read_u32(mem, phys_addr)
end

function ru32(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	#if ((offset + 3) $ offset) & (~UInt64(0xfff)) == 0
	if (offset & (UInt64(0xfff))) < 4093
		# In the same page
		return ru32_fast(cpu, mem, seg, offset)
	else
		# Cross-page access
		return ru32_crosspg(cpu, mem, seg, offset)
	end
end

@inline function rs32(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	return reinterpret(Int32, ru32(cpu, mem, seg, offset))
end

#-----16-----
function ru16_crosspg(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	ret = UInt16(0)
	for i = 0 : 1
		ret += (UInt16(phys_read_u8(mem, logical_to_physical(cpu, seg, offset + i))) << (i << 3))
	end
	return ret
end

@noinline function ru16_fast(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	phys_addr = logical_to_physical(cpu, seg, offset)
	return phys_read_u16(mem, phys_addr)
end

function ru16(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	if (offset & (UInt64(0xfff))) < 4095
		# In the same page
		return ru16_fast(cpu, mem, seg, offset)
	else
		# Cross-page access
		return ru16_crosspg(cpu, mem, seg, offset)
	end
end

@inline function rs16(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	return reinterpret(Int16, ru16(cpu, mem, seg, offset))
end

#-----8-----
function ru8(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	phys_addr = logical_to_physical(cpu, seg, offset)
	return phys_read_u8(mem, phys_addr)
end
function rs8(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	return reinterpret(Int8, ru8(cpu, mem, seg, offset))
end

function ru8_debug(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64)
	phys_addr = logical_to_physical(cpu, seg, offset)
	return phys_read_u8_debug(mem, phys_addr, data)
end

# -----64-----
function wu64_crosspg(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt64)
	for i = 0 : 7
		byte = UInt8((data >> i) & 0xff)
		phys_write_u8(mem, logical_to_physical(cpu, seg, offset + i), byte)
	end
end

@noinline function wu64_fast(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data::UInt64)
	phys_addr = logical_to_physical(cpu, seg, offset)
	phys_write_u64(mem, phys_addr, data)
end

function wu64(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt64)
	#if ((offset + 7) $ offset) & (~UInt64(0xfff)) == 0
	if (offset & (UInt64(0xfff))) < 4089
		# In the same page
		wu64_fast(cpu, mem, seg, offset, data)
	else
		# Cross-page access
		wu64_crosspg(cpu, mem, seg, offset, data)
	end
end

@inline function ws64(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: Int64)
	wu64(cpu, mem, seg, offset, reinterpret(UInt64, data))
end

# -----32-----
function wu32_crosspg(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt32)
	for i = 0 : 3
		byte = UInt8((data >> i) & 0xff)
		phys_write_u8(mem, logical_to_physical(cpu, seg, offset + i), byte)
	end
end

@noinline function wu32_fast(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data::UInt32)
	phys_addr = logical_to_physical(cpu, seg, offset)
	phys_write_u32(mem, phys_addr, data)
end

function wu32(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt32)
	#if ((offset + 7) $ offset) & (~UInt64(0xfff)) == 0
	if (offset & (UInt64(0xfff))) < 4093
		# In the same page
		wu32_fast(cpu, mem, seg, offset, data)
	else
		# Cross-page access
		wu32_crosspg(cpu, mem, seg, offset, data)
	end
end

@inline function ws32(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: Int32)
	wu32(cpu, mem, seg, offset, reinterpret(UInt32, data))
end

# -----16-----
function wu16_crosspg(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt16)
	for i = 0 : 1
		byte = UInt8((data >> i) & 0xff)
		phys_write_u8(mem, logical_to_physical(cpu, seg, offset + i), byte)
	end
end

@noinline function wu16_fast(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data::UInt16)
	phys_addr = logical_to_physical(cpu, seg, offset)
	phys_write_u16(mem, phys_addr, data)
end

function wu16(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt16)
	#if ((offset + 7) $ offset) & (~UInt64(0xfff)) == 0
	if (offset & (UInt64(0xfff))) < 4095
		# In the same page
		wu16_fast(cpu, mem, seg, offset, data)
	else
		# Cross-page access
		wu16_crosspg(cpu, mem, seg, offset, data)
	end
end

@inline function ws16(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: Int16)
	wu16(cpu, mem, seg, offset, reinterpret(UInt16, data))
end

#-----8-----
function wu8(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt8)
	phys_addr = logical_to_physical(cpu, seg, offset)
	phys_write_u8(mem, phys_addr, data)
end

function ws8(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: Int8)
	wu8(cpu, mem, seg, offset, reinterpret(UInt8, data))
end

function wu8_debug(cpu:: CPU, mem:: PhysicalMemory, seg:: Int, offset:: UInt64, data:: UInt8)
	phys_addr = logical_to_physical(cpu, seg, offset)
	phys_write_u8_debug(mem, phys_addr, data)
end

# Port I/O system
function register_port_io_map(cpu:: CPU, device:: IODev)
	for port in keys(device.portlist_r32)
		cpu.port_iomap_dev[@ZB(port)] = device
		cpu.port_iomap_r32[@ZB(port)] = device.portlist_r32[port] 
	end

	for port in keys(device.portlist_r16)
		cpu.port_iomap_dev[@ZB(port)] = device
		cpu.port_iomap_r16[@ZB(port)] = device.portlist_r16[port] 
	end

	for port in keys(device.portlist_r8)
		cpu.port_iomap_dev[@ZB(port)] = device
		cpu.port_iomap_r8[@ZB(port)] = device.portlist_r8[port] 
	end

	for port in keys(device.portlist_w32)
		cpu.port_iomap_dev[@ZB(port)] = device
		cpu.port_iomap_w32[@ZB(port)] = device.portlist_w32[port] 
	end

	for port in keys(device.portlist_w16)
		cpu.port_iomap_dev[@ZB(port)] = device
		cpu.port_iomap_w16[@ZB(port)] = device.portlist_w16[port] 
	end

	for port in keys(device.portlist_w8)
		cpu.port_iomap_dev[@ZB(port)] = device
		cpu.port_iomap_w8[@ZB(port)] = device.portlist_w8[port] 
	end
end

@noinline function port_io_r32(cpu:: CPU, addr:: UInt64)
	if cpu.port_iomap_r32[@ZB(addr)] == false
		println("I/O port $(hex(addr)) has no 32-bit read IO function. Trying to fall back to 8-bit read.") 
		return UInt32(port_io_r8(cpu, addr)) | 
			(UInt32(port_io_r8(cpu, addr + 1)) << 8) |
			(UInt32(port_io_r8(cpu, addr + 2)) << 16) |
			(UInt32(port_io_r8(cpu, addr + 3)) << 24)
	else
		return UInt32(cpu.port_iomap_r32[@ZB(addr)](cpu.port_iomap_dev[@ZB(addr)], addr))
	end
end

@noinline function port_io_r16(cpu:: CPU, addr:: UInt64)
	if cpu.port_iomap_r16[@ZB(addr)] == false
		println("I/O port 0x$(hex(addr)) has no 16-bit read IO function. Trying to fall back to 8-bit read.") 
		return UInt16(port_io_r8(cpu, addr)) | 
			(UInt16(port_io_r8(cpu, addr + 1)) << 8)
	else
		return UInt16(cpu.port_iomap_r16[@ZB(addr)](cpu.port_iomap_dev[@ZB(addr)], addr))
	end
end

@noinline function port_io_r8(cpu:: CPU, addr:: UInt64)
	if cpu.port_iomap_r8[@ZB(addr)] == false
		println("r8 : Unregistered I/O port 0x$(hex(addr))") 
		return UInt8(0)
	end
	return UInt8(cpu.port_iomap_r8[@ZB(addr)](cpu.port_iomap_dev[@ZB(addr)], addr))
end

@noinline function port_io_w32(cpu:: CPU, addr:: UInt64, data:: UInt32)
	if cpu.port_iomap_w32[@ZB(addr)] == false
		println("I/O port 0x$(hex(addr)) has no 32-bit write IO function. Trying to fall back to 8-bit write.")
		port_io_w8(UInt8(data & 0xff), addr)
		port_io_w8(UInt8((data & 0xff00) >>> 8 ), addr + 1)
		port_io_w8(UInt8((data & 0xff0000) >>> 16 ), addr + 2)
		port_io_w8(UInt8((data & 0xff000000) >>> 24 ), addr + 3)
	else
		cpu.port_iomap_w32[@ZB(addr)](cpu.port_iomap_dev[@ZB(addr)], addr, data)
	end
	return nothing
end

@noinline function port_io_w16(cpu:: CPU, addr:: UInt64, data:: UInt16)
	if cpu.port_iomap_w16[@ZB(addr)] == false
		println("I/O port 0x$(hex(addr)) has no 16-bit write IO function. Trying to fall back to 8-bit write.")
		port_io_w8(UInt8(data & 0xff), addr)
		port_io_w8(UInt8((data & 0xff00) >>> 8 ), addr + 1)
	else
		cpu.port_iomap_w16[@ZB(addr)](cpu.port_iomap_dev[@ZB(addr)], addr, data)
	end
	return nothing
end

@noinline function port_io_w8(cpu:: CPU, addr:: UInt64, data:: UInt8)
	if cpu.port_iomap_w8[@ZB(addr)] == false
		println("w8 : Unregistered I/O port 0x$(hex(addr))")
		return nothing
	end
	cpu.port_iomap_w8[@ZB(addr)](cpu.port_iomap_dev[@ZB(addr)], addr, data)
	return nothing
end

# Execution engine

require("Instructions.jl")

# CPU functions
function exec(cpu:: CPU, mem:: PhysicalMemory)
	println("----- Start -----")
	
	dump(cpu)
	cpu.segment = -1;
	if cpu.jit_enabled
		block = find_jl_block(cpu, mem)
		block.nb_exec += 1
		block.exec(cpu, mem)
		update_clock(g_clock, block.nb_instr)
		@code_native(block.exec(cpu,mem))

		rflags_compute!(cpu)
	else
		cpu.this_instr_len = 0
		cpu.ip_addend = 0
		b = emu_fetch8_advance(cpu, mem)
		println(hex(b))
		cpu.emu_insn_tbl[b](cpu, mem, UInt16(b))
		update_clock(g_clock, UInt64(1))
	end
	println("  -------------")
	dump(cpu)
	println("----- End -----")
end

function loop(cpu:: CPU, mem:: PhysicalMemory)
	local b:: UInt8
	while true
		exec(cpu, mem)
	end
end

function reset(cpu:: CPU)
	# Volume 3, Chapter 9.1.4 First instruction executed.
	# Volume 3, Chapter 9.10, Fig 9-3
	@rip!(cpu, 0x000000000000FFF0)
	@sreg!(cpu, CS, 0xF000)
	@sreg_base!(cpu, CS, 0xFFFF0000)
	@sreg!(cpu, DS, 0)
	@sreg_base!(cpu, DS, 0x0)
	@sreg!(cpu, ES, 0)
	@sreg_base!(cpu, ES, 0x0)
	@sreg!(cpu, SS, 0)
	@sreg_base!(cpu, SS, 0x0)
	@reg_w_named!(cpu, RSP, 0)

	# Volume 3, Chapter 9.1.2, Table 9-1
	cpu.rflags = UInt64(0x02)
	cpu.cr0 = UInt64(0x60000010)
	cpu.cr2 = 0
	cpu.cr3 = 0
	cpu.cr4 = 0
	@sreg!(cpu, FS, 0)
	@sreg_base!(cpu, ES, 0x0)
	@sreg!(cpu, GS, 0)
	@sreg_base!(cpu, SS, 0x0)
	@reg_w_named!(cpu, EAX, 0)
	@reg_w_named!(cpu, ECX, 0)
	@reg_w_named!(cpu, EBX, 0)
	@reg_w_named!(cpu, ESP, 0)
	@reg_w_named!(cpu, EBP, 0)
	@reg_w_named!(cpu, ESI, 0)
	@reg_w_named!(cpu, EDI, 0)
end

function dump(cpu:: CPU)
	# The x64-only CPU info. is not shown
	@printf( "CS:RIP=%016x:%016x\nRAX=%016x  RBX=%016x	RCX=%016x  RDX=%016x\nRSI=%016x  RDI=%016x	RBP=%016x  RSP=%016x\nRIP=%016x RFL=%016x [%c%c%c%c%c%c%c]\n",
			  @sreg_base(cpu, CS),
			  @rip(cpu),
			  @reg_r_named(cpu, RAX),
			  @reg_r_named(cpu, RBX),
			  @reg_r_named(cpu, RCX),
			  @reg_r_named(cpu, RDX),
			  @reg_r_named(cpu, RSI),
			  @reg_r_named(cpu, RDI),
			  @reg_r_named(cpu, RBP),
			  @reg_r_named(cpu, RSP),
			  @rip(cpu),
			  cpu.rflags,
			  (cpu.rflags & CPU_DF != 0) ? 'D' : '-',
			  (cpu.rflags & CPU_OF != 0) ? 'O' : '-',
			  (cpu.rflags & CPU_SF != 0) ? 'S' : '-',
			  (cpu.rflags & CPU_ZF != 0) ? 'Z' : '-',
			  (cpu.rflags & CPU_AF != 0) ? 'A' : '-',
			  (cpu.rflags & CPU_PF != 0) ? 'P' : '-',
			  (cpu.rflags & CPU_CF != 0) ? 'C' : '-'
			  )
end

function interrupt_for_c_hw(opaque:: Ptr{Void}, irq:: Cint, level:: Cint)
	#= The first two arguments are useless.
	   They exist to match the callback function signature in qemu_irq.

	   TODO: APIC =#
	if (level)
		interrupt(g_cpu)
	else
		clear_interrupt(g_cpu)
	end
end

function interrupt(cpu:: CPU)
end

function clear_interrupt(cpu:: CPU)
end
