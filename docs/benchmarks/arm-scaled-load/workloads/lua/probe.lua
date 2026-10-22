local total=0
for i=1,10000 do total=total+i end
assert(total==50005000)
local a={};for i=1,2048 do a[i]=(i*7919)%65521 end
table.sort(a);for i=2,#a do assert(a[i-1]<=a[i]) end
local funcs={};for i=1,100 do local x=i;funcs[i]=function(y)return x+y end end
assert(funcs[37](5)==42)
local co=coroutine.create(function()for i=1,64 do coroutine.yield(i*i) end return 99 end)
for i=1,64 do local ok,x=coroutine.resume(co);assert(ok and x==i*i) end
local ok,x=coroutine.resume(co);assert(ok and x==99)
local mt={__add=function(x,y)return setmetatable({n=x.n+y.n},getmetatable(x)) end}
assert((setmetatable({n=19},mt)+setmetatable({n=23},mt)).n==42)
assert((0xffffffffffffffff ~ 0x123456789abcdef0)==0xedcba9876543210f)
assert((-1 >> 63)==1 and (-1 << 63)==math.mininteger)
assert(string.unpack('<I8',string.pack('<I8',0x123456789abcdef0))==0x123456789abcdef0)
assert(string.pack('<d',-0.0)==string.char(0,0,0,0,0,0,0,128))
assert(string.unpack('<d',string.pack('<d',math.pi))==math.pi)
local f=assert(load(string.dump(function(x)return x*7+2 end)));assert(f(6)==44)
local weak=setmetatable({},{__mode='v'});do local v={};v.self=v;weak[1]=v end
collectgarbage('collect');collectgarbage('collect');assert(weak[1]==nil)
local ok,err=pcall(function()error('bounded expected error')end);assert(not ok and err:match('bounded expected error'))
print('mixed-lua-probe: 50005000 / 42 / 64 / bits / pack / gc / errors')
