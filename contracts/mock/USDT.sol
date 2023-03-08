// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract USDT is ERC20PresetMinterPauser {
  constructor() ERC20PresetMinterPauser("Tether USD", "USDT") {
    _mint(_msgSender(), 1_000_000 * 1e6);
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}
