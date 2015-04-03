//
// Created by yizhuolin on 15/3/27.
// Copyright (c) 2015 aaronyi. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface EFDarwinNotificationCenter : NSObject

+ (EFDarwinNotificationCenter *)defaultCenter;

+ (void)setDefaultApplicationGroupIdentifier:(NSString *)identifier;

- (instancetype)initWithApplicationGroupIdentifier:(NSString *)identifier;

// name must not be empty
- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName object:(id)anObject;

- (void)postNotification:(NSNotification *)notification;
- (void)postNotificationName:(NSString *)aName object:(id)anObject;

// If identifier is nil or Application Group is not configured correctly, userinfo will be ignored
- (void)postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo;

- (void)removeObserver:(id)observer;
- (void)removeObserver:(id)observer name:(NSString *)aName object:(id)anObject;

- (id <NSObject>)addObserverForName:(NSString *)name object:(id)obj queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *note))block;

// clean temp resources
- (void)clean;
@end