-- 调用一个类方法
runClassMethod('ViewController', 'runClassMethod');


-- 修复传参
fixMethod("ZKCrash", "instanceMethodMightCrash:", 1, false,
          function(instance, originInvocation, originArguments)
              if (originArguments[0]==nil) then
                  print("fix it")
                  -- 调用一个实例方法取值
                  local ab = runInstanceMethod("ViewController", "runInstanceMethod:b:", {"a", "b"})
                  -- 修改参数(lua的数组下标以1开始)
                  originArguments[0+1] = ab
                  setInvocationArgs(originInvocation, originArguments)
                  runInvocation(originInvocation)
              else
                  -- 不满足修复条件的跳过此修复
                  print("no fix")
                  runInvocation(originInvocation)
              end
          end
);

-- 修复返回值
fixMethod("ZKCrash", "instanceMethodReturnMightCrash", 1, false,
        function(instance, originInvocation, originArguments)
            -- 调用一个实例方法 并获取返回值
            local a = runInstanceMethod("ViewController", "runInstanceMethodGetInt")
            -- 修改返回值
            setInvocationReturnValue(originInvocation, a)
        end
);
