// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import CoreTendApp

// Byte-for-byte the same entry point as Sources/CoreTend/main.swift, below the
// header. SwiftPM will not let two targets share a source directory, so this
// file exists only to satisfy that; everything that differs between the two
// products is decided by `Distribution`, which reads the CORETEND_APP_STORE
// flag once and turns it into data.
//
// `DistributionTests.theTwoEntryPointsAreIdentical` fails if these two files
// stop matching, because a second entry point that drifts is precisely the
// failure this arrangement exists to prevent.
CoreTendApp.main()
