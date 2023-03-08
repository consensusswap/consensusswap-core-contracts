// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract CSSMock is ERC20PresetMinterPauser {
  constructor() ERC20PresetMinterPauser("Consensus Mock Token", "CSSM") {
    _mint(_msgSender(), 1_000_000 * 1e18);
  }
}
