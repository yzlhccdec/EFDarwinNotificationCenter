//
// Created by yizhuolin on 15/3/27.
// Copyright (c) 2015 aaronyi. All rights reserved.
//

#import "EFDarwinNotificationCenter.h"

static NSString *const kDefaultDirectoryName = @"com.aaronyi.efnotifications";
static NSString *DefaultAppGroupIdentifier = nil;

static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, void const *object, CFDictionaryRef userInfo);


@interface _EFNotificationObserverProxy : NSObject <NSCopying>

@property (nonatomic, weak, readonly) EFDarwinNotificationCenter *notificationCenter;
@property (nonatomic, weak, readonly) id                         observer;

+ (instancetype)observerProxyForNotificationCenter:(EFDarwinNotificationCenter *)notificationCenter observer:(id)observer;
@end

@implementation _EFNotificationObserverProxy

- (instancetype)initWithNotificationCenter:(EFDarwinNotificationCenter *)notificationCenter observer:(id)observer
{
    self = [super init];
    if (self) {
        _notificationCenter = notificationCenter;
        _observer           = observer;
    }
    
    return self;
}

+ (instancetype)observerProxyForNotificationCenter:(EFDarwinNotificationCenter *)notificationCenter observer:(id)observer
{
    return [[self alloc] initWithNotificationCenter:notificationCenter observer:observer];
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass:[_EFNotificationObserverProxy class]]) {
        return NO;
    }
    
    return [_notificationCenter isEqual:((_EFNotificationObserverProxy *) other)->_notificationCenter]
    && [_observer isEqual:((_EFNotificationObserverProxy *) other)->_observer];
}

- (NSUInteger)hash
{
    return [_notificationCenter hash] ^ [_observer hash];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end;

@implementation EFDarwinNotificationCenter
{
    NSString             *_appGroupIdentifier;
    NSNotificationCenter *_notificationCenter;
    NSMutableDictionary  *_observers;
}

+ (EFDarwinNotificationCenter *)defaultCenter
{
    static dispatch_once_t            token;
    static EFDarwinNotificationCenter *instance;
    
    dispatch_once(&token, ^{
        instance = [[EFDarwinNotificationCenter alloc] init];
    });
    
    return instance;
}

+ (void)setDefaultApplicationGroupIdentifier:(NSString *)identifier
{
    DefaultAppGroupIdentifier = identifier;
}

- (instancetype)init
{
    return [self initWithApplicationGroupIdentifier:nil];
}

- (instancetype)initWithApplicationGroupIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self) {
        _appGroupIdentifier = identifier;
        _notificationCenter = [NSNotificationCenter new];
        _observers          = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)dealloc
{
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    
    for (_EFNotificationObserverProxy *observer in _observers.allKeys) {
        CFNotificationCenterRemoveEveryObserver(center, (__bridge const void *) (observer));
    }
}

- (void)postNotification:(NSNotification *)notification
{
    [self postNotificationName:notification.name object:notification.object userInfo:notification.userInfo];
}

- (void)__postNotificationNamed:(NSString *)name
{
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center, (__bridge CFStringRef) name, NULL, NULL, YES);
}

- (void)postNotificationName:(NSString *)aName object:(id)anObject
{
    [self postNotificationName:aName object:anObject userInfo:nil];
}

- (void)postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    if (aName == nil) {
        return;
    }
    
    [self __saveUserInfo:aUserInfo name:aName];
    [self __postNotificationNamed:aName];
}

- (void)removeObserver:(id)observer
{
    [_notificationCenter removeObserver:observer];
    
    _EFNotificationObserverProxy *notificationObserverProxy = [self __observerProxyForObserver:observer];
    
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterRemoveEveryObserver(center, (__bridge const void *) notificationObserverProxy);
    
    [_observers removeObjectForKey:notificationObserverProxy];
}

- (void)removeObserver:(id)observer name:(NSString *)aName object:(id)anObject
{
    if (aName == nil) {
        [self removeObserver:observer];
        return;
    }
    
    CFNotificationCenterRef const center                     = CFNotificationCenterGetDarwinNotifyCenter();
    _EFNotificationObserverProxy  *notificationObserverProxy = [self __observerProxyForObserver:observer];
    NSMutableDictionary           *observerEntries           = _observers[notificationObserverProxy];
    
    [_notificationCenter removeObserver:observer name:aName object:anObject];
    CFNotificationCenterRemoveObserver(center, (__bridge const void *) (notificationObserverProxy), (__bridge CFStringRef) aName, NULL);
    [observerEntries removeObjectForKey:aName];
    
    if (observerEntries.count == 0) {
        [_observers removeObjectForKey:notificationObserverProxy];
    }
}

// return the same proxy for same observer
- (_EFNotificationObserverProxy *)__observerProxyForObserver:(id)observer
{
    _EFNotificationObserverProxy *notificationObserverProxy = [_EFNotificationObserverProxy observerProxyForNotificationCenter:self observer:observer];
    return _observers[notificationObserverProxy] ? [_observers[notificationObserverProxy] allValues].firstObject : notificationObserverProxy;
}

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName object:(id)anObject
{
    if (aName == nil) {
        return;
    }
    
    [_notificationCenter addObserver:observer selector:aSelector name:aName object:nil];
    
    _EFNotificationObserverProxy *efNotificationObserver = [self __observerProxyForObserver:observer];
    
    [self __addObserver:efNotificationObserver name:aName object:anObject];
}

- (void)__addObserver:(_EFNotificationObserverProxy *)observer name:(NSString *)name object:(NSString *)obj
{
    NSMutableDictionary *observerEntries = _observers[observer];
    if (!observerEntries) {
        observerEntries = [NSMutableDictionary dictionary];
        _observers[observer] = observerEntries;
    }
    
    if (observerEntries[name]) {
        return;
    }
    
    observerEntries[name] = observer;
    
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, (__bridge const void *) observer, notificationCallback, (__bridge CFStringRef) name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, void const *object, CFDictionaryRef userInfo) {
    _EFNotificationObserverProxy *efNotificationObserver = (__bridge _EFNotificationObserverProxy *) observer;
    
    NSDictionary *data = [efNotificationObserver.notificationCenter __loadUserInfoWithName:(__bridge NSString *) name];
    [efNotificationObserver.notificationCenter->_notificationCenter postNotificationName:(__bridge NSString *) name
                                                                                  object:nil
                                                                                userInfo:data];
}

- (id <NSObject>)addObserverForName:(NSString *)name object:(id)obj queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *note))block
{
    if (name == nil) {
        return nil;
    }
    
    id observer = [_notificationCenter addObserverForName:name object:nil queue:queue usingBlock:block];
    
    _EFNotificationObserverProxy *efNotificationObserver = [self __observerProxyForObserver:observer];
    
    [self __addObserver:efNotificationObserver name:name object:obj];
    
    return observer;
}

- (void)__saveUserInfo:(NSDictionary *)userInfo name:(NSString *)name
{
    NSString *filePath = [self __filePathForUserInfoWithIdentifier:name];
    if (filePath) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:userInfo];
        [data writeToFile:filePath atomically:YES];
    }
}

- (NSDictionary *)__loadUserInfoWithName:(NSString *)name
{
    NSString *filePath = [self __filePathForUserInfoWithIdentifier:name];
    if (filePath) {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        return data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
    }
    
    return nil;
}

- (NSString *)__filePathForUserInfoWithIdentifier:(NSString *)name
{
    NSString *directoryPath = [self __notificationDirectoryPath];
    if (directoryPath == nil) {
        return nil;
    }
    NSString *fileName = [NSString stringWithFormat:@"%@.nc", name];
    NSString *filePath = [directoryPath stringByAppendingPathComponent:fileName];
    
    return filePath;
}

- (NSString *)__notificationDirectoryPath
{
    NSFileManager *fileManager     = [NSFileManager defaultManager];
    NSString      *groupIdentifier = [self __appGroupIdentifier];
    if (groupIdentifier.length == 0) {
        return nil;
    }
    NSURL    *appGroupContainer     = [fileManager containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
    NSString *appGroupContainerPath = [appGroupContainer path];
    NSString *directoryPath         = [appGroupContainerPath stringByAppendingPathComponent:kDefaultDirectoryName];
    
    [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    return directoryPath;
}

- (NSString *)__appGroupIdentifier
{
    return _appGroupIdentifier.length ? _appGroupIdentifier : DefaultAppGroupIdentifier;
}

- (void)clean
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *directoryPath = [self __notificationDirectoryPath];
        [[NSFileManager defaultManager] removeItemAtPath:directoryPath error:nil];
    });
}

@end