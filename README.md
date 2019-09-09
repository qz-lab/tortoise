# Tortoise - a 64-bit RISC-V SOC
 **tortoise** is a 64-bit RISC-V SOC, written in systemVerilog. I hope it would outrun rabbits one day, even claws slowly at first.
 
**乌龟** 是一个64位的RISC-V片上系统，使用systemVerilog语言开发。即使一开始爬得慢，但是希望它最终能够跑赢兔子。

This project is inspired by 2 great books: `Computer Organization and Design - THE HARDWARE/SOFTWARE INTERFACE` and `Computer Architecture - A Quantitative Approach`. Thanks the authors `David A. Patterson` and `John L. Hennessy`. And also thanks the open-source project [pulp-platform/ariane](https://github.com/pulp-platform/ariane), which helps me a lot on the implementation details.

本工程受到两本书启发：`计算机组织与设计 - 软硬件接口`和`计算机体系结构 - 量化研究方法`，在此对两位作者`David A. Patterson` and `John L. Hennessy`表示感谢。同时感谢开源工程[pulp-platform/ariane](https://github.com/pulp-platform/ariane)，提供了大量实现细节方面的参考。

This is not a simple project and I have worked on it for more than one months from the scratch. However, only about a half is completed and the function has not been verified yet, partly due to the lack of development environment :-(

这不是一个简单的工程，我已经从零开始在上面花了一个多月的时间。尽管如此，只完成了大约一半的工作，而且没有对功能进行验证。这部分是由于我手头没有相关的开发环境。

Even though it merely includes basic calculations and load/store operations, I think it's appropriate to upload it to github before I switch to a new computer.

尽管现在它只包含基本的运算和载入/储存操作，我觉得在我更换新的电脑之前应当把它上传到GitHub。

Here is the list of targets in the next few months:
以下是我计划在接下来的几个月要完成的目标列表：
- [ ] debug system with JTAG ports
- [ ] CSRs and interrupt handling
- [ ] AXI system bus and interconnect
- [ ] 2-level caches and TLB component

Note: All the codes just pass through syntax-check by verilator, which can NOT be compiled or verified functionally. I don't even have the time to write a humble Makefile. If you're insterested, please be patient.
注意：目前所有的代码只是通过了verilator的语法检查，并不能进行编译和功能验证，我甚至还没来得及写一个基本的Makefile。如果有感兴趣的同学，请耐心等待。
