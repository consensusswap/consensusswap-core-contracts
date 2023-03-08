// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract WBTC is ERC20PresetMinterPauser {
  constructor() ERC20PresetMinterPauser("Wrapped BTC", "WBTC") {
    _mint(_msgSender(), 1_000_000 * 1e8);
  }

  function decimals() public view virtual override returns (uint8) {
    return 8;
  }
}
