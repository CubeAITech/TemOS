local call = component.invoke;
local screen = component.list("screen")() 
local gpu = component.list("gpu")() 
local gpu_proxy = component.proxy(gpu) 

gpu_proxy.bind(screen) 
gpu_proxy.set(1, 1, "Полностью рабочий TemOS")
