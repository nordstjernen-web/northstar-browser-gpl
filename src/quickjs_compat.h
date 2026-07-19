/* Northstar — browser-side shims for QuickJS APIs absent from upstream quickjs-ng.
 * Copyright 2026 Andreas Røsdal
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef NS_QUICKJS_COMPAT_H
#define NS_QUICKJS_COMPAT_H

#include <stdint.h>

#include <quickjs.h>

JSContext *JS_GetCallerRealm(JSContext *ctx);
JSContext *JS_GetFunctionRealm(JSContext *ctx, JSValueConst func_obj);

int JS_RepointArrayBuffer(JSContext *ctx, JSValueConst obj, uint8_t *data,
                          size_t byte_length);

JSClassID ns_new_class_id(JSClassID *pclass_id);

#endif
