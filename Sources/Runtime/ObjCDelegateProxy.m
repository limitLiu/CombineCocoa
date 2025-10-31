#import "ObjCDelegateProxy.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define HIDDEN_ARGUMENT_COUNT 2

#define SEL_VALUE(x) [NSValue valueWithPointer:(x)]
#define CLASS_VALUE(x) [NSValue valueWithNonretainedObject:(x)]

id __nonnull EX_extract_argument_at_index(NSInvocation *__nonnull invocation,
                                          NSUInteger index) {
  const char *argumentType =
      [invocation.methodSignature getArgumentTypeAtIndex:index];

#define RETURN_VALUE(type)                                                     \
  else if (strcmp(argumentType, @encode(type)) == 0) {                         \
    type val = 0;                                                              \
    [invocation getArgument:&val atIndex:index];                               \
    return @(val);                                                             \
  }

  // Skip const type qualifier.
  if (argumentType[0] == 'r') {
    argumentType++;
  }

  if (strcmp(argumentType, @encode(id)) == 0 ||
      strcmp(argumentType, @encode(Class)) == 0 ||
      strcmp(argumentType, @encode(void (^)(void))) == 0) {
    __unsafe_unretained id argument = nil;
    [invocation getArgument:&argument atIndex:index];
    return argument;
  }
  RETURN_VALUE(char)
  RETURN_VALUE(short)
  RETURN_VALUE(int)
  RETURN_VALUE(long)
  RETURN_VALUE(long long)
  RETURN_VALUE(unsigned char)
  RETURN_VALUE(unsigned short)
  RETURN_VALUE(unsigned int)
  RETURN_VALUE(unsigned long)
  RETURN_VALUE(unsigned long long)
  RETURN_VALUE(float)
  RETURN_VALUE(double)
  RETURN_VALUE(BOOL)
  RETURN_VALUE(const char *)
  else {
    NSUInteger size = 0;
    NSGetSizeAndAlignment(argumentType, &size, NULL);
    NSCParameterAssert(size > 0);
    uint8_t data[size];
    [invocation getArgument:&data atIndex:index];

    return [NSValue valueWithBytes:&data objCType:argumentType];
  }
}

NSArray *EX_extract_arguments(NSInvocation *invocation) {
  NSUInteger numberOfArguments = invocation.methodSignature.numberOfArguments;
  NSUInteger numberOfVisibleArguments =
      numberOfArguments - HIDDEN_ARGUMENT_COUNT;
  NSCParameterAssert(numberOfVisibleArguments >= 0);
  NSMutableArray *arguments =
      [NSMutableArray arrayWithCapacity:numberOfVisibleArguments];
  for (NSUInteger index = HIDDEN_ARGUMENT_COUNT; index < numberOfArguments;
       ++index) {
    [arguments addObject:EX_extract_argument_at_index(invocation, index)
                             ?: [NSNull null]];
  }
  return arguments;
}

BOOL EX_is_method_with_description_void(struct objc_method_description method) {
  return strncmp(method.types, @encode(void), 1) == 0;
}

BOOL EX_is_method_signature_void(NSMethodSignature *__nonnull methodSignature) {
  const char *methodReturnType = methodSignature.methodReturnType;
  return strcmp(methodReturnType, @encode(void)) == 0;
}

@interface ObjCDelegateProxy () {
  id __weak __forwardToDelegate;
}

@property(nonatomic, strong) id strongForwardDelegate;
@end

static NSMutableDictionary<NSValue *, NSSet<NSValue *> *>
    *voidSelectorsPerClass;

@implementation ObjCDelegateProxy

+ (NSSet *)collectVoidSelectorsForProtocol:(Protocol *)protocol {
  NSMutableSet *selectors = [NSMutableSet set];
  unsigned int protocolMethodCount = 0;
  struct objc_method_description *pMethods = protocol_copyMethodDescriptionList(
      protocol, NO, YES, &protocolMethodCount);
  for (unsigned int i = 0; i < protocolMethodCount; ++i) {
    struct objc_method_description method = pMethods[i];
    if (EX_is_method_with_description_void(method)) {
      [selectors addObject:SEL_VALUE(method.name)];
    }
  }
  free(pMethods);

  unsigned int numberOfBaseProtocol = 0;
  Protocol *__unsafe_unretained *pSubprotocols =
      protocol_copyProtocolList(protocol, &numberOfBaseProtocol);
  for (unsigned int i = 0; i < numberOfBaseProtocol; ++i) {
    [selectors
        unionSet:[self collectVoidSelectorsForProtocol:pSubprotocols[i]]];
  }
  free(pSubprotocols);
  return selectors;
}

+ (void)initialize {
  @synchronized(ObjCDelegateProxy.class) {
    if (voidSelectorsPerClass == nil) {
      voidSelectorsPerClass = [NSMutableDictionary dictionary];
    }

    NSMutableSet *voidSelectors = [NSMutableSet set];

#define CLASS_HIERARCHY_MAX_DEPTH 100

    NSInteger classHierarchyDepth = 0;
    Class targetClass = NULL;

    for (classHierarchyDepth = 0, targetClass = self;
         classHierarchyDepth < CLASS_HIERARCHY_MAX_DEPTH && targetClass != nil;
         ++classHierarchyDepth,
        targetClass = class_getSuperclass(targetClass)) {
      unsigned int count;
      Protocol *__unsafe_unretained *pProtocols =
          class_copyProtocolList(targetClass, &count);

      for (unsigned int i = 0; i < count; i++) {
        NSSet *selectorsForProtocol =
            [self collectVoidSelectorsForProtocol:pProtocols[i]];
        [voidSelectors unionSet:selectorsForProtocol];
      }

      free(pProtocols);
    }

    if (classHierarchyDepth == CLASS_HIERARCHY_MAX_DEPTH) {
      NSLog(@"Detected weird class hierarchy with depth over %d. Starting with "
            @"this class -> %@",
            CLASS_HIERARCHY_MAX_DEPTH, self);
#if DEBUG
      abort();
#endif
    }
    voidSelectorsPerClass[CLASS_VALUE(self)] = voidSelectors;
  }
}

- (id)_forwardToDelegate {
  return __forwardToDelegate;
}

- (void)_setForwardToDelegate:(id)forwardToDelegate
               retainDelegate:(BOOL)retainDelegate {
  __forwardToDelegate = forwardToDelegate;
  if (retainDelegate) {
    self.strongForwardDelegate = forwardToDelegate;
  } else {
    self.strongForwardDelegate = nil;
  }
}

- (BOOL)hasWiredImplementationForSelector:(SEL)selector {
  return [super respondsToSelector:selector];
}

- (BOOL)voidDelegateMethodsContain:(SEL)selector {
  @synchronized(ObjCDelegateProxy.class) {
    NSSet *voidSelectors = voidSelectorsPerClass[CLASS_VALUE(self.class)];
    NSAssert(voidSelectors != nil, @"Set of allowed methods not initialized");
    return [voidSelectors containsObject:SEL_VALUE(selector)];
  }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
  NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
  if (!signature) {
    signature = [self._forwardToDelegate methodSignatureForSelector:aSelector];
  }
  return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
  BOOL isVoid = EX_is_method_signature_void(anInvocation.methodSignature);
  NSArray *arguments = nil;
  if (isVoid) {
    arguments = EX_extract_arguments(anInvocation);
    [self _sentMessage:anInvocation.selector withArguments:arguments];
  }

  if (self._forwardToDelegate &&
      [self._forwardToDelegate respondsToSelector:anInvocation.selector]) {
    [anInvocation invokeWithTarget:self._forwardToDelegate];
  }

  if (isVoid) {
    [self _methodInvoked:anInvocation.selector withArguments:arguments];
  }
}

- (void)_sentMessage:(SEL)selector withArguments:(NSArray *)arguments {
}

- (void)_methodInvoked:(SEL)selector withArguments:(NSArray *)arguments {
}

- (void)dealloc {
}

@end
