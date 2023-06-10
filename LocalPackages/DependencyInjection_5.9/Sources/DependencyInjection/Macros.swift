//
//  Macros.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if swift(>=5.9)

@attached(member, names: named(Dependencies), named(DynamicDependencies), named(DependencyProvider), named(DynamicDependencyProvider), named(dependencyProvider), named(_currentDependencies), named(getAllDependencyProviderKeyPaths(from:)), named(makeDependencies), named(make))
@attached(peer, names: suffixed(_DependencyProvider), suffixed(_DependencyProvider_allKeyPaths), suffixed(_DynamicDependencyProvider))
public macro Injectable() = #externalMacro(module: "DependencyInjectionMacros", type: "InjectableMacro")

@attached(accessor)
public macro Injected(_: AnyKeyPath? = nil) = #externalMacro(module: "DependencyInjectionMacros", type: "InjectedMacro")

#endif
