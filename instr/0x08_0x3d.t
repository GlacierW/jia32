# Operation function & type
op_funcs ::Array{Function, 1} = [ |, -, -, - ]
op_types ::Array{Int, 1} = [ OP_OR, OP_SBB, OP_SUB, OP_CMP ]

# Get the lower/higher part of opcode
opc_h ::UInt8 = (opc & 0xf0) >> 4
opc_l ::UInt8 =  opc & 0x0f		

op_func ::Function = op_funcs[@ZB(opc_h)]
op_type ::Int = op_types[@ZB(opc_h)]

# Operand type
ot ::Type
ot_width ::UInt8

if cpu.operand_size == 16
	
	if opc_l == 0x0c || opc_l == 0x0d 
		if opc_l & 0x01 == 0
			ot		 = UInt8
			ot_width = 8

			f_fch = fetch8_advance
		else
			ot		 = UInt16
			ot_width = 16

			f_fch = fetch16_advance
		end

		imm = f_fch(cpu, mem)
j=		b = UInt64($$imm)
		if op_type == OP_SBB
j=			rflags_compute!(cpu)
j=			b += (cpu.rflags & CPU_CF)
		end

j=		a = UInt64(@reg_r(cpu, $$ot, 0))
		if op_type != OP_CMP
j=			r = $$op_func(a, b)
j=			@reg_w!(cpu, $$ot, 0, r % $$ot)
		end
	else
call= modrm modrm,mod,rm,reg,disp,is_reg,ev_reg,t_addr,seg
		if is_reg
			if opc_l & 0x02 == 0
				r_dst = ev_reg
				r_src = reg
			else
				r_dst = reg
				r_src = ev_reg
			end

			if opc_l & 0x01 == 0
				ot		 = UInt8
				ot_width = 8
			else
				ot		 = UInt16
				ot_width = 16
			end

j=			a = UInt64(@reg_r(cpu, $$ot, $$r_dst))
j=			b = UInt64(@reg_r(cpu, $$ot, $$r_src))
			if op_type == OP_SBB 
j=				rflags_compute!(cpu)		
j=				b += (cpu.rflags & CPU_CF)
			end
			
			if op_type != OP_CMP
j=				r = $$op_func(a, b)
j=				@reg_w!(cpu, $$ot, $$r_dst, r % $$ot)
			end

		else
			if opc_l & 0x01 == 0
				ot		 = UInt8
				ot_width = 8

				f_ru = ru8
				f_wu = wu8
			else
				ot		 = UInt16
				ot_width = 16

				f_ru = ru16
				f_wu = wu16
			end

			if opc_l & 0x02 == 0
j=				a = UInt64($$f_ru(cpu, mem, $$seg, t_addr))
j=				b = UInt64(@reg_r(cpu, $$ot, $$seg))
				
				if op_type != OP_CMP
					if op_type == OP_SBB
j=						rflags_compute!(cpu)
j=						b += (cpu.rflags & CPU_CF)
					end
j=					r = $$op_func(a, b)
j=					$$f_wu(cpu, mem, $$seg, t_addr, r)
				end
			else
j=				a = UInt64(@reg_r(cpu, $$ot, $$reg))
j=				b = UInt64($$f_ru(cpu, mem, $$seg, t_addr))
				if op_type != OP_CMP
					if op_type == OP_SBB
j=						rflags_compute!(cpu)		
j=						b += (cpu.rflags & CPU_CF)
					end
j=					r = $$op_func(a, b)
j=					@reg_w!(cpu, $$ot, $$reg, r % $$ot)
				end
			end
		end
	end
  
#= Note on SBB instruction:
	If CF is not set when SBB executes, it is simply a SUB instruction.
	Therefore, at runtime we check CF to decide using SBB or SUB for 
        future RFLAGS lazy computation.
=#
	if op_type == OP_SBB
j=		cpu.lazyf_op = (cpu.rflags & CPU_CF == 0x0) ? OP_SUB : OP_SBB
	else
j=		cpu.lazyf_op = $$op_type
	end
j=	cpu.lazyf_width = $$ot_width
j=	cpu.lazyf_op1 = a
j=	cpu.lazyf_op2 = b

end
