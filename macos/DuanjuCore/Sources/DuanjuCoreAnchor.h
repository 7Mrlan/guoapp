#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 让 Go 静态核心被链接进 Runner 可执行文件（Dart 侧用 DynamicLibrary.process() 查符号）。
FOUNDATION_EXPORT void DjuEnsureCoreLinked(void);

NS_ASSUME_NONNULL_END
