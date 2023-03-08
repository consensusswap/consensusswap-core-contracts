// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract DAI is ERC20PresetMinterPauser {
  constructor() ERC20PresetMinterPauser("DAI Stablecoin", "DAI") {
    _mint(_msgSender(), 1_000_000 * 1e18);
  }
}
