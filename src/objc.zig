//! Minimal Objective-C runtime shim.
//!
//! purrtty drives AppKit (NSApplication / NSWindow / NSView) directly through
//! the Obj-C runtime instead of pulling a third-party binding, so it stays
//! pinned only to libghostty + the system. We need very little: look up
//! classes, send messages, and define one NSView subclass to receive key
//! events and hand them to libghostty.
//!
//! `msgSend` casts the single `objc_msgSend` entrypoint to a typed function
//! pointer per call site — the standard way to call it safely from a non-C
//! language. Always pass the exact argument types the selector expects.

const std = @import("std");

pub const id = ?*opaque {};
pub const Class = ?*opaque {};
pub const SEL = ?*opaque {};
pub const IMP = *const fn () callconv(.c) void;

pub extern "c" fn objc_getClass(name: [*:0]const u8) Class;
pub extern "c" fn sel_registerName(name: [*:0]const u8) SEL;
pub extern "c" fn objc_allocateClassPair(superclass: Class, name: [*:0]const u8, extra: usize) Class;
pub extern "c" fn objc_registerClassPair(cls: Class) void;
pub extern "c" fn class_addMethod(cls: Class, name: SEL, imp: IMP, types: [*:0]const u8) bool;
pub extern "c" fn class_addIvar(cls: Class, name: [*:0]const u8, size: usize, alignment: u8, types: [*:0]const u8) bool;
pub extern "c" fn object_getInstanceVariable(obj: id, name: [*:0]const u8, out: *?*anyopaque) ?*anyopaque;
pub extern "c" fn object_setInstanceVariable(obj: id, name: [*:0]const u8, value: ?*anyopaque) ?*anyopaque;

// The raw dispatch entrypoint. Cast to the right signature before calling.
pub extern "c" fn objc_msgSend() void;

/// `sel("foo:")` — cached-by-the-runtime selector lookup.
pub fn sel(comptime name: [:0]const u8) SEL {
    return sel_registerName(name.ptr);
}

/// `class("NSWindow")`.
pub fn class(comptime name: [:0]const u8) Class {
    return objc_getClass(name.ptr);
}

/// Send `selector` to `target` with `args`, returning `Ret`. The msgSend
/// pointer is reinterpreted to the concrete signature so the C ABI is exact.
pub fn msgSend(comptime Ret: type, target: anytype, selector: SEL, args: anytype) Ret {
    const Args = @TypeOf(args);
    const fields = @typeInfo(Args).@"struct".fields;

    // Build the function-pointer type: (self, SEL, args...) callconv(.c) Ret
    const FnType = switch (fields.len) {
        0 => *const fn (@TypeOf(target), SEL) callconv(.c) Ret,
        1 => *const fn (@TypeOf(target), SEL, fields[0].type) callconv(.c) Ret,
        2 => *const fn (@TypeOf(target), SEL, fields[0].type, fields[1].type) callconv(.c) Ret,
        3 => *const fn (@TypeOf(target), SEL, fields[0].type, fields[1].type, fields[2].type) callconv(.c) Ret,
        4 => *const fn (@TypeOf(target), SEL, fields[0].type, fields[1].type, fields[2].type, fields[3].type) callconv(.c) Ret,
        else => @compileError("add more msgSend arities"),
    };
    const f: FnType = @ptrCast(&objc_msgSend);

    return switch (fields.len) {
        0 => f(target, selector),
        1 => f(target, selector, args[0]),
        2 => f(target, selector, args[0], args[1]),
        3 => f(target, selector, args[0], args[1], args[2]),
        4 => f(target, selector, args[0], args[1], args[2], args[3]),
        else => unreachable,
    };
}

/// `[[Class alloc] init]` convenience.
pub fn alloc(cls: Class) id {
    return msgSend(id, cls, sel("alloc"), .{});
}
pub fn init(obj: id) id {
    return msgSend(id, obj, sel("init"), .{});
}
