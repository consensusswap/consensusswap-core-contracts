/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@&#G5J?7!~~~::::::::::::::::~^^^:::::^:G@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@#GY7~:.                                    5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@#P?^.                                          5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@#Y!.                    ~????????????????????????7B@@@@@@@@@@@@@
@@@@@@@@@@@@@&P!.                       5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@&Y:                          5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@&Y:                      .::^~^7YYYYYYYYYYYYYYYYYYYYYYYYY#@@@@@@@@@@@@@
@@@@@@@@P:                  .^7YPB#&@@@&.                         5@@@@@@@@@@@@@
@@@@@@&7                 :?P#@@@@@@@@@@&.                         5@@@@@@@@@@@@@
@@@@@B:               .7G&@@@@@@@@@&#BBP.                         5@@@@@@@@@@@@@
@@@@G.              .J#@@@@@@@&GJ!^:.                             5@@@@@@@@@@@@@
@@@G.              7#@@@@@@#5~.                                   5@@@@@@@@@@@@@
@@#.             :P@@@@@@#?.                                      5@@@@@@@@@@@@@
@@~             :#@@@@@@J.       .~JPGBBBBBBBBBBBBBBBBBBBBBBBBBBBB&@@@@@@@@@@@@@
@5             .#@@@@@&~       !P&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@~             P@@@@@&^      ^G@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
B             ~@@@@@@7      ^&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
5             5@@@@@#      .#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Y   ..     .. P#####5      7@@@@@@@@@@@@@@@@@@@@@@@@&##########################&
@############B:    .       !@@@@@@@@@@@@@@@@@@@@@@@@5            ..            7
@@@@@@@@@@@@@@:            .#@@@@@@@@@@@@@@@@@@@@@@@~                          7
@@@@@@@@@@@@@@J             ~&@@@@@@@@@@@@@@@@@@@@@?       ......              5
@@@@@@@@@@@@@@#.             ^G@@@@@@@@@@@@@@@@@@#!      .G#####G.            .#
@@@@@@@@@@@@@@@P               !P&@@@@@@@@@@@@@G7.      :G@@@@@@~             ?@
@@@@@@@@@@@@@@@@5                :!JPG####BPY7:        7#@@@@@&!             :#@
@@@@@@@@@@@@@@@@@P:                   ....           !B@@@@@@#~              P@@
@@@@@@@@@@@@@@@@@@#!                             .^J#@@@@@@@Y.              J@@@
@@@@@@@@@@@@@@@@@@@@G~                      .^!JP#@@@@@@@&5^               Y@@@@
@@@@@@@@@@@@@@@@@@@@@@G7.               ?BB#&@@@@@@@@@@#J:                5@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@&P7:            5@@@@@@@@@@&GJ~.                ^B@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@B5?~:.      5@@@@&#G5?~.                  .Y@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#BGP5YJ~~~^^..                      ?#@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                         .?B@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                       ^Y&@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                    ^JB@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                :!5#@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.         ..^!JP#@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&~::^~!7?5PB&@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CSSMarketingDeal
 * @author Consensus party
 * @notice This contract allows the contract owner to select marketers and pay them with the CSS token. The payment will
 * be vested over time, with a configurable unlock period. Marketers can claim their payment at any time, and the amount
 * they receive will be proportional to the time elapsed since the payment was unlocked. The contract owner can select
 * multiple marketers at once and must lock their CSS tokens during the selection process. The contract uses the
 * OpenZeppelin ERC20 and Math libraries to handle token transfers and calculations.
 */
contract CSSMarketingDeal is Ownable {
  struct PaymentSchedule {
    uint256 unlockTime;
    uint256 amount;
    uint256 lastClaimedTime;
  }

  /// @dev An instance of the IERC20 contract that represents the CSS token being used for payments.
  IERC20 public immutable cssToken;
  /// @dev The period of time (in seconds) that must elapse before a payment can be fully claimed.
  uint256 public unlockPeriod;
  /// @dev Mapping from address to payment schedule.
  mapping(address => PaymentSchedule) public payments;

  /**
   * @dev Emitted when a payment is scheduled for a recipient.
   * @param recipient The address of the recipient.
   * @param amount The amount of CSS token scheduled to be paid.
   * @param unlockTime The time when the payment will be unlocked and available to claim.
   */
  event PaymentScheduled(address indexed recipient, uint256 amount, uint256 unlockTime);

  /**
   * @dev Emitted when a payment is claimed by a recipient.
   * @param recipient The address of the recipient.
   * @param amount The amount of CSS token claimed.
   */
  event PaymentClaimed(address indexed recipient, uint256 amount);

  constructor(address cssTokenAddress, uint256 _unlockPeriod) {
    cssToken = IERC20(cssTokenAddress);
    unlockPeriod = _unlockPeriod;
  }

  /**
   * @notice Sets the unlock period for payment schedules.
   * @dev Only callable by the contract owner.
   * @param newUnlockPeriod The new unlock period to set.
   */
  function setUnlockPeriod(uint256 newUnlockPeriod) external onlyOwner {
    require(newUnlockPeriod > 0, "Unlock period must be greater than 0");
    unlockPeriod = newUnlockPeriod;
  }

  /**
   * @dev Schedules payments to the specified addresses.
   *
   * Emits {PaymentScheduled} events.
   *
   * Requirements:
   * - Only the contract owner can call this function.
   * - The contract owner must have approved the transfer of CSS tokens to this contract.
   *
   * @param recipients The addresses to which payments will be made.
   * @param amounts The amounts of CSS tokens to be paid to each recipient.
   */
  function schedulePayments(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
    require(recipients.length == amounts.length && recipients.length > 0, "CSSMarketingDeal: invalid array");

    uint256 totalAmount;
    uint256 unlockTime = block.timestamp + unlockPeriod;

    for (uint256 i; i < recipients.length; i++) {
      address recipient = recipients[i];
      uint256 amount = amounts[i];

      require(recipient != address(0), "CSSMarketingDeal: recipient cannot be zero address");
      require(amount > 0, "CSSMarketingDeal: amount must be greater than zero");
      if (payments[recipient].amount == 0) {
        revert(string(abi.encodePacked("CSSMarketingDeal: already scheduled for ", Strings.toHexString(recipient))));
      }

      totalAmount += amount;
      payments[recipient] = PaymentSchedule({unlockTime: unlockTime, amount: amount, lastClaimedTime: block.timestamp});

      emit PaymentScheduled(recipient, amount, unlockTime);
    }

    // Transfers CSS tokens from the contract owner to this contract
    require(cssToken.transferFrom(msg.sender, address(this), totalAmount), "CSSMarketingDeal: Transfer failed");
  }

  /**
   * @dev Claims payment that has been scheduled for the caller of this function.
   *
   * The amount that can be claimed depends on the current block timestamp and the unlock period.
   *
   * Emits a {PaymentClaimed} event.
   */
  function claimPayment() external {
    address recipient = msg.sender;
    PaymentSchedule storage payment = payments[recipient];
    require(payment.amount > 0, "CSSMarketingDeal: No payment scheduled for caller");

    uint256 claimableAmount = getClaimableAmount(recipient);
    require(claimableAmount > 0, "CSSMarketingDeal: No payment claimable for caller");

    payment.lastClaimedTime = block.timestamp;
    require(cssToken.transfer(recipient, claimableAmount), "CSSMarketingDeal: Transfer failed");

    emit PaymentClaimed(recipient, claimableAmount);
  }

  /**
   * @dev Gets the amount of CSS tokens that can be claimed for the specified payment schedule.
   *
   * The amount that can be claimed depends on the current block timestamp and the unlock period.
   *
   * @param recipient The address to which payments will be made.
   */
  function getClaimableAmount(address recipient) public view returns (uint256) {
    PaymentSchedule storage payment = payments[recipient];
    uint256 passed = Math.min(block.timestamp, payment.unlockTime) - payment.lastClaimedTime;
    return (payment.amount * passed) / unlockPeriod;
  }
}

/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@&#G5J?7!~~~::::::::::::::::~^^^:::::^:G@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@#GY7~:.                                    5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@#P?^.                                          5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@#Y!.                    ~????????????????????????7B@@@@@@@@@@@@@
@@@@@@@@@@@@@&P!.                       5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@&Y:                          5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@&Y:                      .::^~^7YYYYYYYYYYYYYYYYYYYYYYYYY#@@@@@@@@@@@@@
@@@@@@@@P:                  .^7YPB#&@@@&.                         5@@@@@@@@@@@@@
@@@@@@&7                 :?P#@@@@@@@@@@&.                         5@@@@@@@@@@@@@
@@@@@B:               .7G&@@@@@@@@@&#BBP.                         5@@@@@@@@@@@@@
@@@@G.              .J#@@@@@@@&GJ!^:.                             5@@@@@@@@@@@@@
@@@G.              7#@@@@@@#5~.                                   5@@@@@@@@@@@@@
@@#.             :P@@@@@@#?.                                      5@@@@@@@@@@@@@
@@~             :#@@@@@@J.       .~JPGBBBBBBBBBBBBBBBBBBBBBBBBBBBB&@@@@@@@@@@@@@
@5             .#@@@@@&~       !P&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@~             P@@@@@&^      ^G@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
B             ~@@@@@@7      ^&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
5             5@@@@@#      .#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Y   ..     .. P#####5      7@@@@@@@@@@@@@@@@@@@@@@@@&##########################&
@############B:    .       !@@@@@@@@@@@@@@@@@@@@@@@@5            ..            7
@@@@@@@@@@@@@@:            .#@@@@@@@@@@@@@@@@@@@@@@@~                          7
@@@@@@@@@@@@@@J             ~&@@@@@@@@@@@@@@@@@@@@@?       ......              5
@@@@@@@@@@@@@@#.             ^G@@@@@@@@@@@@@@@@@@#!      .G#####G.            .#
@@@@@@@@@@@@@@@P               !P&@@@@@@@@@@@@@G7.      :G@@@@@@~             ?@
@@@@@@@@@@@@@@@@5                :!JPG####BPY7:        7#@@@@@&!             :#@
@@@@@@@@@@@@@@@@@P:                   ....           !B@@@@@@#~              P@@
@@@@@@@@@@@@@@@@@@#!                             .^J#@@@@@@@Y.              J@@@
@@@@@@@@@@@@@@@@@@@@G~                      .^!JP#@@@@@@@&5^               Y@@@@
@@@@@@@@@@@@@@@@@@@@@@G7.               ?BB#&@@@@@@@@@@#J:                5@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@&P7:            5@@@@@@@@@@&GJ~.                ^B@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@B5?~:.      5@@@@&#G5?~.                  .Y@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#BGP5YJ~~~^^..                      ?#@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                         .?B@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                       ^Y&@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                    ^JB@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                :!5#@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.         ..^!JP#@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&~::^~!7?5PB&@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
