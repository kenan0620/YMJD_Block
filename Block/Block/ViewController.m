//
//  ViewController.m
//  Block
//
//  Created by mac on 2019/1/8.
//  Copyright © 2019 伟东云教育. All rights reserved.
//

#import "ViewController.h"

//通过定义声明block
typedef void (^defNoParamAndNoResponse)(void);
typedef int (^defNoParamAndResponse)(void);
typedef void (^defParamAndNoResponse)(int a,NSString *str);
typedef NSDictionary* (^defParamAndResponse)(NSDictionary *dic);

@interface ViewController ()

//block作属性时类型要选择为copy
@property (nonatomic, readwrite, copy) defNoParamAndNoResponse block1;
@property (nonatomic, readwrite, copy) defNoParamAndResponse block2;

@property (nonatomic, readwrite, copy) defParamAndNoResponse block3;

@property (nonatomic, readwrite, copy) defParamAndResponse block4;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self defineAndUseBlock];
    
    [self BlockBottomLayerPrinciple];
    
    [self BlockCache];
}

/**
 block存储（此处只针对说明ARC模式下，MRC请自行学习）
 */
- (void)BlockCache{
    /**
     对于存储我们都不陌生，内存优化，分析，资源存储等。在这里我们分析一下block是怎么存储的。oc程序里存储一般分为五部分：栈区、堆区、全局区、文字常量区、程序代码区。block有三种类型，全局_NSConcreteGlobalBlock、栈_NSConcreteStackBlock、堆_NSConcreteMallocBlock。
     其中，全局块存在全局内存中，相当于单例；栈块存在于栈内存中，作用域仅限于栈内；堆块存在于堆内存中，是一个带引用计数的对象，需要自行管理内存
    
     注意：在 ARC 开启的情况下，将只会有 NSConcreteGlobalBlock 和 NSConcreteMallocBlock 类型的 block。
     
     
     使用过程中如何判断block的位置？
     1、block不访问外界变量
     block即不在堆区，也不在栈区，在代码段中，此时为全局块
     
     2、block访问外界变量
     访问外界变量的block默认存储在堆中，实际是存储在栈中，ARC模式下自动拷贝到堆区。然后自动释放。
     栈上的block，如果其所属的变量作用域结束，该block被放弃，block中的__block也被放弃。为了解决栈块在变量作用域结束之后被释放，需要把block复制到堆中，用以延长生命周期，ARC下，大多情况编译器会自动判是否需要复制。block的复制操作执行的是copy实例方法。block只要调用了copy，栈块就会变为堆块。
     在ARC的Block是配置在栈上的，所以返回函数调用方时，Block变量作用域就结束了，Block会被废弃。种情况编译器会自动完成复制。
     全局_NSConcreteGlobalBlock、栈_NSConcreteStackBlock、堆_NSConcreteMallocBlock经过copy，存储源由程序数据区、栈、堆到程序数据区（不做任何操作）、栈区复制到堆区、引用计数加1。
     Block在堆中copy会造成引用计数增加，这与其他Objective-C对象是一样的。虽然Block在栈中也是以对象的身份存在，但是栈块没有引用计数，因为不需要，我们都知道栈区的内存由编译器自动分配释放。
     不管Block存储域在何处，用copy方法复制都不会引起任何问题。在不确定时调用copy方法即可。在ARC有效时，多次调用copy方法完全没有问题：
     
     3、在copy之后，block变量被copy到堆上。访问的时候forwarding通过转发找到自身的指针
     
     4、block循环引用的时候使用__weak进行解决__weak typeof(self) weakSelf = self;一般有
     //1.使用__weak ClassName
     __block XXViewController* weakSelf = self;
     self.blk = ^{
     NSLog(@"In Block : %@",weakSelf);
     };
     //2.使用__weak typeof(self)
     __weak typeof(self) weakSelf = self;
     self.blk = ^{
     NSLog(@"In Block : %@",weakSelf);
     };
     //3.Reactive Cocoa中的@weakify和@strongify
     @weakify(self);
     self.blk = ^{
     @strongify(self);
     NSLog(@"In Block : %@",self);
     };
     
     */
    
    {
     /**
      NSGlobalBlock 静态block，释放有两种不同的时机：
      
      1、如果这个block引用了外部变量后是栈block，则在定义此block的函数出栈时，block释放。
      2、如果这个blcok引用了外部变量之后是堆block，则其宿主target释放的时候此block才释放。
      
      */
        
        NSLog(@"\n--------------------block的存储域 全局块---------------------\n");
        
        void (^blk)(void) = ^{
            NSLog(@"Global Block");
        };
        blk();
        NSLog(@"%@", [blk class]);
        //
        
        /*
         输出： __NSGlobalBlock__
         
         结论：
         全局块：这种块不会捕捉任何状态（外部的变量），运行时也无须有状态来参与。块所使用的整个内存区域，在编译期就已经确定。
         全局块一般声明在全局作用域中。但注意有种特殊情况，在函数栈上创建的block，如果没有捕捉外部变量，block的实例还是会被设置在程序的全局数据区，而非栈上。
         */
        
    }
    
    {
        /**
         NSMallocBlock 堆区block
         堆区是内存的常驻区域，也叫永久存储区，block一般在函数中定义，最多是个栈block。
         作为一个对象，把它复制到堆中，想要使用它肯定要有一个指针指向它，而指向它的指针是作为property或静态变量出现的（如果不被引用也就没有了常驻于堆区的意义），而实际开发中多使用poperty引用。在堆上不会被复写，但是会增加引用计数
         
         堆中的block无法直接创建，其需要由_NSConcreteStackBlock类型的block拷贝而来(也就是说block需要执行copy之后才能存放到堆中)。由于block的拷贝最终都会调用_Block_copy_internal函数。
         
         在 ARC 中，捕获外部了变量的 block 的类会是 NSMallocBlock 或者 NSStackBlock，如果 block 被赋值给了某个变量，在这个过程中会执行 _Block_copy 将原有的 NSStackBlock 变成 NSMallocBlock；但是如果 block 没有被赋值给某个变量，那它的类型就是 NSStackBlock；没有捕获外部变量的 block 的类会是 NSGlobalBlock 即不在堆上，也不在栈上，它类似 C 语言函数一样会在代码段中。
         
         在非 ARC 中，捕获了外部变量的 block 的类会是 NSStackBlock，放置在栈上，没有捕获外部变量的 block 时与 ARC 环境下情况相同。
         */
        
        NSLog(@"\n--------------------block的存储域 堆块---------------------\n");
        
        int i = 1;
        void (^blk)(void) = ^{
            NSLog(@"Malloc Block, %d", i);
        };
        blk();
        NSLog(@"%@", [blk class]);
        
        /**
         --------------------block的存储域 堆块---------------------
         
         2019-01-08 16:08:45.098306+0800 Block[5779:167549] Malloc Block, 1
         2019-01-08 16:08:45.098400+0800 Block[5779:167549] __NSMallocBlock__
         
         结论：
         堆块：解决块在栈上会被覆写的问题，可以给块对象发送copy消息将它拷贝到堆上。复制到堆上后，块就成了带引用计数的对象了。
         
         在ARC中，以下几种情况栈上的Block会自动复制到堆上：
         - 调用Block的copy方法
         - 将Block作为函数返回值时（MRC时此条无效，需手动调用copy）
         - 将Block赋值给__strong修饰的变量时（MRC时此条无效）
         - 向Cocoa框架含有usingBlock的方法或者GCD的API传递Block参数时
         
         上述代码就是在ARC中，block赋值给__strong修饰的变量，并且捕获了外部变量，block就会自动复制到堆上。

         */
    }
    
    {
        /**
         NSStackBlock 栈区block
         
         函数只有入栈后才能执行，出栈后就释放了。
         栈block一般在函数内部定义，并在函数内部调用；或者在函数外部定义，作为函数的一个参数在函数内部调用。函数出栈时和其他变量或参数一起释放。
         */
        
        NSLog(@"\n--------------------block的存储域 栈块---------------------\n");
        int i = 2;
        __weak void (^blk)(void) = ^{
            NSLog(@"Stack Block, %d", i);
        };
        blk();
        NSLog(@"%@", [blk class]);
        
        /**
         
         2019-01-08 16:11:32.420912+0800 Block[5847:169433] Stack Block, 2
         2019-01-08 16:11:32.421012+0800 Block[5847:169433] __NSStackBlock__
         
         栈块：块所占内存区域分配在栈中，编译器有可能把分配给块的内存覆写掉。
         在ARC中，除了上面四种情况，并且不在global上，block是在栈中。
         */
    }
   
    /**
     GCD中的blockh引用在block销毁的时候释放内部对象
     
     */
    
    /**
     Block的递归调用
     Block内部调用自身，递归调用是很多算法基础，特别是在无法提前预知循环终止条件的情况下。注意：由于Block内部引用了自身，这里必须使用__block避免循环引用问题。
     
     __block return_type (^blockName)(var_type) = [^return_type (var_type varName)
     { if (returnCondition)
     {
     blockName = nil; return;
     } // ... // 【递归调用】 blockName(varName);
     } copy];
     
     //【初次调用】
     blockName(varValue);
     */
    
   
}

/**
 Block 底层实现及原理分析
 
 */
- (void)BlockBottomLayerPrinciple{
    {
        
        
        /**
         如何截获自动变量
         Block的结构，和作为匿名函数的调用机制，那自动变量截获是发生在什么时候呢？
         观察上节代码中__main_block_impl_0结构体（main栈上Block的结构体）的构造函数可以看到，栈上的变量count以参数的形式传入到了这个构造函数中，此处即为变量的自动截获。
         因此可以这样理解：__block_impl结构体已经可以代表Block类了，但在栈上又声明了__main_block_impl_0结构体，对__block_impl进行封装后才来表示栈上的Block类，就是为了获取Block中使用到的栈上声明的变量（栈上没在Block中使用的变量不会被捕获），变量被保存在Block的结构体实例中。
         所以在blk()执行之前，栈上简单数据类型的count无论发生什么变化，都不会影响到Block以参数形式传入而捕获的值。但这个变量是指向对象的指针时，是可以修改这个对象的属性的，只是不能为变量重新赋值。
         */
        /**
         1、block外的变量引用
         
         block 默认是将其复制到其数据结构中来实现访问的。
         block的自动变量截获只针对block内部使用的自动变量（此处为str,str1则没有获取）。因为截获的自动变量会存储于block的结构体内部，导致block体积变大。（此处str复制一份到block内部）
         默认情况下，block只能访问不腻修改局部变量的值
         */
        NSString *str = @"First";
        NSLog(@"block定义前str地址=%p", &str);
        NSString *str1= @"First1";
        defNoParamAndNoResponse block = ^(){
            NSLog(@"%@",str);
            NSLog(@"block定义内部str地址=%p\n", &str);
        };
         NSLog(@"block定义后str地址=%p", &str);
        str = @"Second";
        
        block();
        /**
         输出结果为：
         block定义前str地址=0x7ffee983ba58
         block定义后str地址=0x7ffee983ba58
         First
         block定义内部str地址=0x6000011e51f0
         
         
         定义前后b地址不变都在栈区，定义内部使用地址发生变化：strg从栈区拷贝到堆区，是一个新的对象，不是同一个对象。
         */
    }
    
    {
        /**
         2、__Blcok 修饰外部变量
         __block 修饰外部变量时，block时复制其引用地址来实现访问的。
         此时block内部可以修改外部用__Blcok修饰的值
         
         将其转为C++代码可以发现
         __block int val = 10;
         转换成
         __Block_byref_val_0 val = {
         0,
         &val,
         0,
         sizeof(__Block_byref_val_0),
         10
         };
         
         会发现一个局部变量加上__block修饰符后变为来和block一样的__Block_byref_val_0结构体类型的实例
         此时我们在block内部访问val变量则只需要通过forwarding的成员变量来进行消息转发，再访问val
        */
       __block NSString *str = @"First";
        NSLog(@"block定义前str地址=%p", &str);
        defNoParamAndNoResponse block = ^(){
            str = @"Third";
            NSLog(@"%@",str);
            NSLog(@"block定义内部str地址=%p", &str);
        };
        NSLog(@"block定义后str地址=%p", &str);
        str = @"Second";
        NSLog(@"block定义后1str地址=%p", &str);
        NSLog(@"调用block前 str%@", str);
        block();
        NSLog(@"调用block后 str%@", str);
        /**
         block定义前str地址=0x7ffeef0bda18
         block定义后str地址=0x600000f8d048
         block定义后1str地址=0x600000f8d048
         调用block前 strSecond
         Third
         block定义内部str地址=0x600000f8d048
         调用block后 strThird
         
         流程：
         1. 声明 str 为 __block （__block 所起到的作用就是只要观察到该变量被 block 所持有，就将“外部变量”在栈中的内存地址放到了堆中。）
         2. block定义前：str在栈中。
         3. block定义内部： 将外面的str拷贝到堆中，并且使外面的str和里面的str是一个。此后所有的使用都是堆中的地址
         4. block定义后：外面的b和里面的str是一个。
         5. block调用前：str的值还未被修改。
         6. block调用后：str的值在block内部被修改。
         
         */
    }
    
    {
        NSLog(@"\n--------------------block调用 指针---------------------\n");
        
        NSString *c = @"ccc";
        NSLog(@"block定义前：c=%@, c指向的地址=%p, c本身的地址=%p", c, c, &c);
        void (^cBlock)(void) = ^{
            NSLog(@"block定义内部：c=%@, c指向的地址=%p, c本身的地址=%p", c, c, &c);
        };
        NSLog(@"block定义后：c=%@, c指向的地址=%p, c本身的地址=%p", c, c, &c);
        cBlock();
        NSLog(@"block调用后：c=%@, c指向的地址=%p, c本身的地址=%p", c, c, &c);
        
        /* 输出结果
         block定义前：c=ccc, c指向的地址=0x10165a538, c本身的地址=0x7ffee07c99a8
         block定义后：c=ccc, c指向的地址=0x10165a538, c本身的地址=0x7ffee07c99a8
         block定义内部：c=ccc, c指向的地址=0x10165a538, c本身的地址=0x600002f072f0
         block调用后：c=ccc, c指向的地址=0x10165a538, c本身的地址=0x7ffee07c99a8
         
         c指针本身在block定义中和外面不是一个，但是c指向的地址一直保持不变。
         1. block定义前：c指向的地址在堆中， c指针本身的地址在栈中。
         2. block定义内部：c指向的地址在堆中， c指针本身的地址在堆中（c指针本身和外面的不是一个，但是指向的地址和外面指向的地址是一样的）。
         3. block定义后：c不变，c指向的地址在堆中， c指针本身的地址在栈中。
         4. block调用后：c不变，c指向的地址在堆中， c指针本身的地址在栈中。
         */
    }
    
    {
        NSLog(@"\n--------------------block调用 指针并修改值---------------------\n");
        
        NSMutableString *d = [NSMutableString stringWithFormat:@"ddd"];
        NSLog(@"block定义前：d=%@, d指向的地址=%p, d本身的地址=%p", d, d, &d);
        void (^dBlock)(void) = ^{
            NSLog(@"block定义内部：d=%@, d指向的地址=%p, d本身的地址=%p", d, d, &d);
            d.string = @"测试dddddd";
        };
        NSLog(@"block定义后：d=%@, d指向的地址=%p, d本身的地址=%p", d, d, &d);
        dBlock();
        NSLog(@"block调用后：d=%@, d指向的地址=%p, d本身的地址=%p", d, d, &d);
        
        /*输出结果
         block定义前：d=ddd, d指向的地址=0x60000393a280, d本身的地址=0x7ffeec2a3970
         block定义后：d=ddd, d指向的地址=0x60000393a280, d本身的地址=0x7ffeec2a3970
         block定义内部：d=ddd, d指向的地址=0x60000393a280, d本身的地址=0x600003939c10
         block调用后：d=测试dddddd, d指向的地址=0x60000393a280, d本身的地址=0x7ffeec2a3970
         
         d指针本身在block定义中和外面不是一个，但是d指向的地址一直保持不变。
         在block调用后，d指向的堆中存储的值发生了变化。
         */
    }
    
    {
        NSLog(@"\n--------------------block调用 __block修饰的指针---------------------\n");
        
        __block NSMutableString *e = [NSMutableString stringWithFormat:@"eee"];
        NSLog(@"block定义前：e=%@, e指向的地址=%p, e本身的地址=%p", e, e, &e);
        void (^eBlock)(void) = ^{
            NSLog(@"block定义内部：e=%@, e指向的地址=%p, e本身的地址=%p", e, e, &e);
            e = [NSMutableString stringWithFormat:@"new-eeeeee"];
        };
        NSLog(@"block定义后：e=%@, e指向的地址=%p, e本身的地址=%p", e, e, &e);
        eBlock();
        NSLog(@"block调用后：e=%@, e指向的地址=%p, e本身的地址=%p", e, e, &e);
        
        /*
         
          block定义前：e=eee, e指向的地址=0x6000024ef510, e本身的地址=0x7ffee70e7938
          block定义后：e=eee, e指向的地址=0x6000024ef510, e本身的地址=0x6000024ef7d8
          block定义内部：e=eee, e指向的地址=0x6000024ef510, e本身的地址=0x6000024ef7d8
          block调用后：e=new-eeeeee, e指向的地址=0x6000024f0570, e本身的地址=0x6000024ef7d8
         
         从block定义内部使用__block修饰的e指针开始，e指针本身的地址由栈中改变到堆中，即使出了block，也在堆中。
         在block调用后，e在block内部重新指向一个新对象,e指向的堆中的地址发生了变化。
         */
    }
    
   /**
    Block优点：捕获外部变量，降低代码分散程度，高内聚
    缺点：循环引用造成内存泄露
    
    实现原理：C语言的函数指针 函数指针即函数在内存中的地址，通过这个地址可以达到调用函数的目的。
    本质：本质上也是一个OC对象，它内部也有个isa指针
    源码：
    struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
    };
    
    struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    // 构造函数（类似于OC的init方法），返回结构体对象
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
    }
    };
    
    // 封装了block执行逻辑的函数
    static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_2r__m13fp2x2n9dvlr8d68yry500000gn_T_main_c60393_mi_0);
    }
    
    static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    } __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
    int main(int argc, const char * argv[]) {
    // @autoreleasepool
    { __AtAutoreleasePool __autoreleasepool;
        // 定义block变量
        void (*block)(void) = &__main_block_impl_0(
                                                   __main_block_func_0,
                                                   &__main_block_desc_0_DATA
                                                   );
        
        // 执行block内部的代码
        block->FuncPtr(block);
    }
    return 0;
}

    */
    
    /**
     使用及解决：
     在block内部使用的是将外部变量的拷贝到堆中的（基本数据类型直接拷贝一份到堆中，对象类型只将在栈中的指针拷贝到堆中并且指针所指向的地址不变）。
     __block修饰符的作用：是将block中用到的变量，拷贝到堆中，并且外部的变量本身地址也改变到堆中。
     __block不能解决循环引用，需要在block执行尾部将变量设置成nil
     __weak可以解决循环引用，block在捕获weakObj时，会对weakObj指向的对象进行弱引用。
     使用__weak时，可在block开始用局部__strong变量持有，以免block执行期间对象被释放。
     全局块不引用外部变量，所以不用考虑。
     堆块引用的外部变量，不是原始的外部变量，是拷贝到堆中的副本。
     栈块本身就在栈中，引用外部变量不会拷贝到堆中。
     __weak 本身是可以避免循环引用的问题的，但是其会导致外部对象释放了之后，block 内部也访问不到这个对象的问题，我们可以通过在 block 内部声明一个 __strong 的变量来指向 weakObj，使外部对象既能在 block 内部保持住，又能避免循环引用的问题。
     __block 本身无法避免循环引用的问题，但是我们可以通过在 block 内部手动把 blockObj 赋值为 nil 的方式来避免循环引用的问题。另外一点就是 __block 修饰的变量在 block 内外都是唯一的，要注意这个特性可能带来的隐患。
     
     */
    
    /**
     注意事项：
     不能修改自动变量的值是因为：block捕获的是自动变量的const值，名字一样，不能修改
     
     可以修改静态变量的值：静态变量属于类的，不是某一个变量。由于block内部不用调用self指针。所以block可以调用。
     
     */
}

/**
 Blocks对象是C级别的语法和运行时特性，与标准的C函数类似。除了可执行代码外，还可能包含变量自动绑定（栈）和内存托管（堆）
 Block是OC对于闭包的实现
 
 定义方式：
 可以嵌套定义，定义Block方法和定义函数方法类似
 Block可以定义在方法内部或外部
 只有调用Block的时候，才会执行Block闭包内的代码
 Block的本质是对象，使代码高聚合
 
 Block表达式可截获所使用的自动变量的值。
 截获：保存自动变量的瞬间值。
 因为是“瞬间值”，所以声明Block之后，即便在Block外修改自动变量的值，也不会对Block内截获的自动变量值产生影响。
 
 自动变量截获的值为Block声明时刻的瞬间值，保存后就不能改写该值，如需对自动变量进行重新赋值，需要在变量声明前附加__block说明符，这时该变量称为__block变量。
 
 自动变量值为一个对象情况
 当自动变量为一个类的对象，且没有使用__block修饰时，虽然不可以在Block内对该变量进行重新赋值，但可以修改该对象的属性。
 如果该对象是个Mutable的对象，例如NSMutableArray，则还可以在Block内对NSMutableArray进行元素的增删：
 

 */

- (void)defineAndUseBlock{
    /** 定义及调用
     return_type表示返回的对象/关键字等(可以是void，并省略)
     
     blockName表示block的名称
     
     var_type表示参数的类型(可以是void，并省略)
     
     varName表示参数名称
     
     return_type (^blockName)(var_type) = ^return_type (var_type varName) { // ... };
     
     blockName(var);
     */
    {
        //1、无参数无返回值 (NoParamAndNoResponseBlock 为Block名，可以根据使用意义自己定义)
        void(^NoParamAndNoResponseBlock)(void) = ^(void){
            NSLog(@"无参数无返回值");
        };
        
        //调用方式如下：
        NoParamAndNoResponseBlock();
    }
    
    {
        //2、有参数无返回值
        void(^ParamAndNoResponseBlock)(NSString *str) = ^(NSString *strParam){
            NSLog(@"有参数无返回值：%@",strParam);
        };
        
        ParamAndNoResponseBlock(@"传入的参数数据");
    }
    
    {
        //3、有参数有返回值
        int (^ParamAndResponseBlock)(int ,int) = ^(int a,int b){
            NSLog(@"有参数有返回值%d",a + b);
            return a + b;
        };
        
        ParamAndResponseBlock(9,5);
        
        
        NSDictionary* (^block)(NSString *str, NSDictionary *dic) = ^NSDictionary* (NSString *str, NSDictionary *dic){
            
            
            NSLog(@"有参数有返回值:%@,%@",str , dic);
            
            return dic;
        };
        
        block(@"字符串",@{@"test":@"test1",@"dex":@"dexvalue",});
    }
    
    {
        //4、有参数无返回值
        void(^ParamAndNoResponse)(NSArray *array) = ^(NSArray *array1){
            NSLog(@"有参数无返回值%@",array1);
        };
        
        ParamAndNoResponse(@[@(1),@(23),@"sdgf",@"sdfdfgd"]);
    }
    
    
    //通过宏定义调用如下
    self.block1 = ^{
        NSLog(@"block1无参数无返回值");
    };
    self.block1();
    
    self.block2 = ^int{
        NSLog(@"block2无参数画有返回值");
        return 2;
    };
    self.block2();
    
    self.block3 = ^(int a, NSString *str) {
        NSLog(@"%d,%@",a,str);
    };
    self.block3(3,@"3字符串");
    
    self.block4 = ^NSDictionary *(NSDictionary *dic) {
        NSLog(@"%@,",dic);
        return dic;
    };
    self.block4(@{@"sj":@"res"});
    
}



@end
