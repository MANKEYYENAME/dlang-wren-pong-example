module wrenmain;

import wren.compiler;
import wren.vm;
import wren.value;
import std.file, std.string, std.path;
import io = std.stdio;
import core.stdc.stdio;
import rl = raylib;

static void writeFn(WrenVM* vm, const(char)* text) @nogc
{
	printf("%s", text);
}

static void errorFn(WrenVM* vm, WrenErrorType errorType,
					const(char)* module_, int line,
					const(char)* msg) @nogc
{
	switch (errorType) with(WrenErrorType)
	{
		case WREN_ERROR_COMPILE:
		{
			printf("[%s line %d] [Error] %s\n", module_, line, msg);
			break;
		} 
		case WREN_ERROR_STACK_TRACE:
		{
			printf("[%s line %d] in %s\n", module_, line, msg);
			break;
		}
		case WREN_ERROR_RUNTIME:
		{
			printf("[Runtime Error] %s\n", msg);
			break;
		}
		default:
		{
			printf("Unknown Error\n");
			break;
		}
	}
}

WrenLoadModuleResult loadWrenModule(WrenVM* vm, const(char)* name)
{
    WrenLoadModuleResult result;
    result.source = modules[name.fromStringz].src.toStringz;
    return result;
}

struct MethodHandle
{
  WrenHandle* handle;
  WrenVM* vm;
  this(WrenVM* vm, const(char)* signature){
    handle = wrenMakeCallHandle(vm, signature);
    this.vm = vm;
  }

  WrenInterpretResult call()
  {
    return wrenCall(vm, handle);
  }

  ~this(){
    wrenReleaseHandle(vm, handle);
  }
}

void wren_assert(WrenInterpretResult result){
  assert(result == WrenInterpretResult.WREN_RESULT_SUCCESS);
}

void wren_assert(WrenInterpretResult result, lazy string msg){
  assert(result == WrenInterpretResult.WREN_RESULT_SUCCESS, msg);
}

int wren_main()
{
	WrenConfiguration config;
	wrenInitConfiguration(&config);
	config.writeFn = &writeFn;
	config.errorFn = &errorFn;
    config.bindForeignMethodFn = &bindForeignMethod;
    config.loadModuleFn = cast(typeof(config.loadModuleFn)) &loadWrenModule;
	
	WrenVM* vm = wrenNewVM(&config);
	scope(exit) wrenFreeVM(vm);

	const(char)* module_ = "main";
  string scriptSource = readText(buildNormalizedPath(thisExePath.dirName, "main.wren"));
	const(char)* script = scriptSource.toStringz;
    initCoreModule();
    
    wren_assert(wrenInterpret(vm, module_, script));

    auto startHandle = MethodHandle(vm, "start()");
    auto updateHandle = MethodHandle(vm, "update(_)");
    auto exitHandle = MethodHandle(vm, "exit()");
    auto drawHandle = MethodHandle(vm, "draw()");

    wrenEnsureSlots(vm, 1);
    wrenGetVariable(vm, "main", "SrlGame", 0);
    auto gameEngineClass = wrenGetSlotHandle(vm, 0);
    scope(exit) wrenReleaseHandle(vm, gameEngineClass);

    wrenSetSlotHandle(vm, 0, gameEngineClass);
    wren_assert(startHandle.call());
    rl.InitWindow(windata.w, windata.h, windata.title);
    scope(exit) rl.CloseWindow();

    while(!rl.WindowShouldClose())
    {
        wrenEnsureSlots(vm, 2);
        wrenSetSlotHandle(vm, 0, gameEngineClass);
        wrenSetSlotDouble(vm, 1, rl.GetFrameTime());
        wren_assert(updateHandle.call());
        rl.BeginDrawing();
            rl.ClearBackground(rl.Colors.BLACK);
            wrenEnsureSlots(vm, 1);
            wrenSetSlotHandle(vm, 0, gameEngineClass);
            wren_assert(drawHandle.call());
        rl.EndDrawing();
    }
    wrenEnsureSlots(vm, 1);
    wrenSetSlotHandle(vm, 0, gameEngineClass);
    wren_assert(exitHandle.call());
    return 0;
}

void initCoreModule()
{
    modules["core"] = WrenStaticModule(q{
        class Window{
            foreign static init(width, height, title)
        }
      }, [
      "Window": StaticClass([
        "init(_,_,_)": cast(WrenForeignMethodFn) &windowInit,
      ]),
    ]);
    modules["renderer"] = WrenStaticModule(q{
        class Renderer{
            foreign static drawCircle(x, y, radius)
            foreign static drawRect(x, y, w, h)
            foreign static drawText(text, x, y, h)
        }
      },[
      "Renderer": StaticClass([
        "drawCircle(_,_,_)": function(WrenVM* vm) @nogc{
            int x = cast(int) wrenGetSlotDouble(vm, 1);
            int y = cast(int) wrenGetSlotDouble(vm, 2);
            float radius = cast(float) wrenGetSlotDouble(vm, 3);
            rl.DrawCircle(x, y, radius, rl.Colors.WHITE);
        },
        "drawRect(_,_,_,_)": function(WrenVM* vm) @nogc{
            int x = cast(int) wrenGetSlotDouble(vm, 1);
            int y = cast(int) wrenGetSlotDouble(vm, 2);
            int w = cast(int) wrenGetSlotDouble(vm, 3);
            int h = cast(int) wrenGetSlotDouble(vm, 4);
            rl.DrawRectangle(x, y, w, h, rl.Colors.WHITE);
        },
        "drawText(_,_,_,_)": function(WrenVM* vm) @nogc{
          auto text = wrenGetSlotString(vm, 1);
          int x = cast(int) wrenGetSlotDouble(vm, 2);
          int y = cast(int) wrenGetSlotDouble(vm, 3);
          int h = cast(int) wrenGetSlotDouble(vm, 4);
          x -= rl.MeasureText(text, h) / 2;
          y -= h / 2;
          rl.DrawText(text, x, y, h, rl.Colors.WHITE);
        }
      ]),
    ]);
    modules["input"] = WrenStaticModule(q{
        class Input{
            foreign static isDown(str)
        }
      }, [
      "Input": StaticClass([
        "isDown(_)": cast(WrenForeignMethodFn) function(WrenVM* vm){
            import std.conv;
            const(char)* str = wrenGetSlotString(vm, 1);
            auto key = str.fromStringz.to!(rl.KeyboardKey);
            bool a = rl.IsKeyDown(key);
            wrenSetSlotBool(vm, 0, a);
        },
      ]),
    ]);
}

WinData windata;
struct WinData{
  int w = 640;
  int h = 480;
  const(char)* title;
}
void windowInit(WrenVM* vm) 
{
  windata.w = cast(int) wrenGetSlotDouble(vm, 1);
  windata.h = cast(int) wrenGetSlotDouble(vm, 2);
  windata.title = wrenGetSlotString(vm, 3).fromStringz.toStringz;
}


WrenForeignMethodFn bindForeignMethod(
    WrenVM* vm,
    const(char)* module_,
    const(char)* className,
    bool isStatic,
    const(char)* signature) @nogc
{
  if (auto module_f = module_.fromStringz in modules){
    if (auto class_f = className.fromStringz in module_f.classes){
      if(isStatic) if (auto method_f = signature.fromStringz in class_f.methods){
        return *method_f; 
      }
    }
  }
  return null;
}

WrenStaticModule[string] modules;

struct StaticClass{
  WrenForeignMethodFn[string] methods;
}

struct WrenStaticModule
{
  string src;
  StaticClass[string] classes;
}