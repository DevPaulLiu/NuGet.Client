// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

namespace NuGet.SolutionRestoreManager
{
    /// <summary>
    /// Contains target framework metadata needed for restore operation. Compared to IVsTargetFrameworkInfo2, this adds support for CentralPackageVersions
    /// </summary>
    public interface IVsTargetFrameworkInfo3 : IVsTargetFrameworkInfo2
    {
        /// <summary>
        /// Collection of central package versions.
        /// </summary>
        IVsReferenceItems CentralPackageVersions { get; }
    }
}
