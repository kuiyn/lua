local vtable =
	(function()
	local ffi = require "ffi"
	local ffi_cast, ffi_typeof = ffi.cast, ffi.typeof
	local interface_ptr = ffi_typeof("void***")

	local function entry(instance, i, ct)
		return ffi_cast(ct, ffi_cast(interface_ptr, instance)[0][i])
	end

	local function bind(instance, i, ct)
		local t = ffi_typeof(ct)
		local fnptr = entry(instance, i, t)
		return function(...)
			return fnptr(instance, ...)
		end
	end

	local function thunk(i, ct)
		local t = ffi_typeof(ct)
		return function(instance, ...)
			return entry(instance, i, t)(instance, ...)
		end
	end

	local hook =
		(function()
		local C = ffi.C

		local v_ptr = ffi_typeof("void*")
		local ui_ptr = ffi_typeof("uintptr_t**")
		local in_ptr = ffi_typeof("intptr_t")
		local ul_ptr = ffi_typeof("unsigned long[1]")
		ffi.cdef "int VirtualProtect(void*, unsigned long, unsigned long, unsigned long*)"

		local hook = {hooks = {}}

		function hook.new(instance, i, ct, callback)
			local t = ffi_typeof(ct)
			local old_prot = ul_ptr()

			local instance_ptr = ffi_cast(ui_ptr, instance)[0]
			local instance_void = ffi_cast(v_ptr, instance_ptr + i)

			hook.hooks[i] = instance_ptr[i]
			C.VirtualProtect(instance_void, 4, 4, old_prot)
			instance_ptr[i] = ffi_cast(in_ptr, ffi_cast(v_ptr, ffi_cast(t, callback)))
			C.VirtualProtect(instance_void, 4, old_prot[0], old_prot)

			return setmetatable(
				{
					call = ffi_cast(t, hook.hooks[i]),
					uninstall = function()
						C.VirtualProtect(instance_void, 4, 4, old_prot)
						instance_ptr[i] = hook.hooks[i]
						C.VirtualProtect(instance_void, 4, old_prot[0], old_prot)
						hook.hooks[i] = nil
					end
				},
				{
					__call = function(self, ...)
						return self.call(...)
					end
				}
			)
		end

		return hook.new
	end)()

	return {
		entry = entry,
		bind = bind,
		thunk = thunk,
		hook = hook
	}
end)()

return vtable
