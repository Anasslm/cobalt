// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>
//
// This header provides information defined by hardware parameters, such as
// the address map. In the future, it should be generated automatically as
// part of the SoC generation process.

#pragma once

#include <stdint.h>

// Base addresses provided at link time
extern void *__bootrom_base_addr__;
extern void *__llc_base_addr__;
extern void *__uart_base_addr__;
extern void *__i2c_base_addr__;
extern void *__spih_base_addr__;
extern void *__gpio_base_addr__;
extern void *__slink_base_addr__;
extern void *__vga_base_addr__;
extern void *__clint_base_addr__;
extern void *__plic_base_addr__;
extern void *__dma_base_addr__;
extern void *__axirt_base_addr__;
extern void *__axirtgrd_base_addr__;
extern void *__bus_err_base_addr__;
extern void *__clic_base_addr__;
extern void *__usb_base_addr__;
extern void *__spm_base_addr__;
extern void *__dram_base_addr__;


// Default boot baudrate
static const uint32_t __BOOT_BAUDRATE = 115200;

