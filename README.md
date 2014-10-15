UnityPlugin
===========

This is an example native-code plugin for Unity 4.x demonstrating how to perform various kinds of callbacks, recurring callbacks, and data buffer marshaling back into your C# scripts. I pulled these simple examples out of a project I'm working on because I didn't find the Unity documentation useful, nor was it easy to find concise or efficient tutorials. There is a lot of horrible, horrible and just plain wrong information about data-types, delegates, and C# marshaling out there. I had to piece a great deal of information together from many different sources, including:

 - [Communicating C# to C++](http://forum.unity3d.com/threads/communicating-c-with-c.89930/)
 - [Mono: Interop with Native Libraries](http://www.mono-project.com/docs/advanced/pinvoke/)
 - [Creating iOS Plugins for Unity](http://blog.mediarain.com/2013/03/creating-ios-plugins-for-unity/)
 - [Stackoverflow: Calling C# Code from Unmanaged C](http://stackoverflow.com/questions/9731990/calling-c-sharp-code-from-unmanaged-c)
 
I'll put some top-level information here, but read the comments in `UnityPlugin.cs` and `UnityPlugin.m` for the real details about how everything works together, how to keep yourself from crashing Unity by calling back on the wrong thread(s), how to do proper setup/teardown, how to manage delegate and callback lifecycles, and how to (try to) minimize copy-overhead if you are using these techniques to flow real-time data between your native code and Unity/C#.


The Unity Plugin
---
 **For Mac or iOS**: an XCode UnityPlugin project which creates a 32-bit `UnityPlugin.bundle`. Note the comments about disabling ARC, (required for 32-bit on Mac, which is required for Unity 4.x) and in general this is a better "best-practices" template .h/.m and XCode project for building your own plugin.

 **For Windows**: _TBD_ (feel free to fork/contribute a pull-request - 99% of the UnityPlugin.m code is pure ANSI-C - it's just a matter of doing different debug logging and writing a different message-pump and recurring timer).
 
 **For Linux**: _TBD_ (again, feel free to fork/contribute)

Unity Example Project
---
The test Unity project `UnityPluginTest` is simply a default scene with a cube with the `UnityPlugin.cs` script component attached to it. When run results of the example are purely Console `Debug.Log` output.

Setup / Installation / Tips
---
 - Before you can run the Unity example project's default scene you'll need to build the native plugin and place it into the `UnityPluginTest/Assets/Plugin` folder, otherwise you'll get the dreaded `DllNotFoundException: UnityPlugin` error.
 - If you still get a `DllNotFoundException: UnityPlugin` error or some variation thereof, double check that XCode built you a 32-bit version of the project and not a 64-bit one. Unity only loads 32-bit bundles. The plugin project specifically tries to build universal bundle binaries (continaing both 64-bit and 32-bit code) so that this example continues to work with 64-bit Unity5, but XCode may decide to change the settings and only give you 64-bit - it is pesky this way.
 - I find it useful to look at both the Unity console and the system log (Console app) while debugging plugins, and I always use a simple prefix (like 'UnityPlugin:') in my logging code so that I can filter the system log for the output from the plugin. Here's an example of what Console/System-Log output looks like when you open Unity, run the sample, and exit Unity.

```
10/15/14 10:41:04.901 AM Unity[20962]: UnityPlugin: initializer
10/15/14 10:41:04.910 AM Unity[20962]: UnityPlugin: reply_during_call
10/15/14 10:41:04.910 AM Unity[20962]: UnityPlugin: set_recurring_reply(6622,0x19bd10c8)
10/15/14 10:41:04.911 AM Unity[20962]: UnityPlugin: poll_data(6622,0xbfffc9c8,0xbfffc9cc)
10/15/14 10:41:04.911 AM Unity[20962]: UnityPlugin: set_recurring_reply(6622,0x19bd1188)
10/15/14 10:41:06.911 AM Unity[20962]: UnityPlugin: recurring invocation loop
10/15/14 10:41:06.911 AM Unity[20962]: UnityPlugin: block is <__NSMallocBlock__: 0x19c3ae50>
10/15/14 10:41:06.913 AM Unity[20962]: UnityPlugin: block is <__NSMallocBlock__: 0x19c25c80>
10/15/14 10:41:25.399 AM Unity[20962]: UnityPlugin: finalizer
```

 - Here's an example of the Unity console output:
 
```
testing callbacks on object:6630
one-time callback on Cube (UnityEngine.GameObject)
polled 862 bytes into C# as System.Byte[]
recurring on Cube (UnityEngine.GameObject) called at 1.940374
recurring data push on Cube (UnityEngine.GameObject) called at 1.940374
transferred 21 bytes into C# as System.Byte[]
recurring on Cube (UnityEngine.GameObject) called at 3.935837
recurring data push on Cube (UnityEngine.GameObject) called at 3.935837
transferred 491 bytes into C# as System.Byte[]
recurring on Cube (UnityEngine.GameObject) called at 5.952033
recurring data push on Cube (UnityEngine.GameObject) called at 5.952033
transferred 668 bytes into C# as System.Byte[]
```
 
 - It's worth understanding that Unity doesn't unload your bundle/dll/.so until the application exits, which means that each compile/debug cycle you need to 1. remove the old plugin from your project, 2. exit unity, 3. relaunch Unity and open your project, 4. re-add your newly buyilt plugin to your project.
 - Because you will be launching and re-launching Unity to try out your plugin so many times, and because some of your crashes will be random, some will be when Unity shuts down, and some may happen because you've forgotten to clear a callback long-since expired, you will want to do the bulk of your testing with a small, simple, quick-to-load Unity project which is really just a unit test of your plugin, and even with this small test you will want to make sure you save any work frequently - Unity is going to crash many, many times during your custom plugin development effort.

