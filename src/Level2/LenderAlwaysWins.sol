// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/mininterfaces.sol";

/// @notice A LenderAlwaysWins is a smart contract escrow that facilitates fixed-duration loans
///         for a specific user and debt-collateral pair.
contract LenderAlwaysWins {
    // Errors

    error OnlyApproved();
    error Deactivated();
    error Default();
    error NoDefault();
    error NotRollable();
    // Data Structures

    Request[] public requests;
    struct Request { // A loan begins with a borrow request. It specifies:
        uint256 amount; // the amount they want to borrow,
        uint256 interest; // the annualized percentage they will pay as interest,
        uint256 loanToCollateral; // the loan-to-collateral ratio they want,
        uint256 duration; // and the length of time until the loan defaults.
        bool active; // Any lender can clear an active loan request.
    } 

    Loan[] public loans;
    struct Loan { // A request is converted to a loan when a lender clears it.
        Request request; // The terms of the loan are saved, along with:
        uint256 amount; // the amount of debt owed,
        uint256 collateral; // the amount of collateral pledged,
        uint256 expiry; // the time when the loan defaults,
        bool rollable; // whether the loan can be rolled over,
        address lender; // and the lender's address.
    }

    // Facilitates transfer of lender ownership to new address
    mapping(uint256 => address) public approvals;

    // Immutables

    // This address owns the collateral in escrow.
    address private immutable owner;
    // This token is borrowed against.
    ERC20 public immutable collateral;
    // This token is lent.
    ERC20 public immutable debt;
    // This contract created the LenderAlwaysWins

    // This makes the code look prettier.
    uint256 private constant decimals = 1e18;

    // Initialization

    constructor (address o, ERC20 c, ERC20 d) {
        owner = o;
        collateral = c;
        debt = d;
    }

    // Borrower

    /// @notice request a loan with given parameters
    /// @notice collateral is taken at time of request
    /// @param amount of debt tokens to borrow
    /// @param interest to pay (annualized % of 'amount')
    /// @param loanToCollateral debt tokens per collateral token pledged
    /// @param duration of loan tenure in seconds
    /// @param reqID index of request in requests[]
    function request (
        uint256 amount,
        uint256 interest,
        uint256 loanToCollateral,
        uint256 duration
    ) external returns (uint256 reqID) {
        reqID = requests.length;
        requests.push(
            Request(amount, interest, loanToCollateral, duration, true)
        );
        collateral.transferFrom(msg.sender, address(this), collateralFor(amount, loanToCollateral));

    }

    /// @notice cancel a loan request and return collateral
    /// @param reqID index of request in requests[]
    function rescind (uint256 reqID) external {
        if (msg.sender != owner) 
            revert OnlyApproved();


        Request storage req = requests[reqID];

        if (!req.active)
            revert Deactivated();
        
        req.active = false;
        collateral.transfer(owner, collateralFor(req.amount, req.loanToCollateral));
        
    }

    /// @notice repay a loan to recoup collateral
    /// @param loanID index of loan in loans[]
    /// @param repaid debt tokens to repay
    function repay (uint256 loanID, uint256 repaid) external {
        Loan storage loan = loans[loanID];

        if (block.timestamp > loan.expiry) 
            revert Default();
        
        uint256 decollateralized = loan.collateral * repaid / loan.amount;

         {
            loan.amount -= repaid;
            loan.collateral -= decollateralized;
        }

        debt.transferFrom(msg.sender, loan.lender, repaid);
        collateral.transfer(owner, decollateralized);

    }

    /// @notice roll a loan over
    /// @notice uses terms from request
    /// @param loanID index of loan in loans[]
    function roll (uint256 loanID) external {
        Loan storage loan = loans[loanID];
        Request memory req = loan.request;

        if (block.timestamp > loan.expiry) 
            revert Default();

        if (!loan.rollable)
            revert NotRollable();

        uint256 newCollateral = collateralFor(loan.amount, req.loanToCollateral) - loan.collateral;
        uint256 newDebt = interestFor(loan.amount, req.interest, req.duration);

        loan.amount += newDebt;
        loan.expiry += req.duration;
        loan.collateral += newCollateral;
        
        collateral.transferFrom(msg.sender, address(this), newCollateral);
    }

    /// @notice delegate voting power on collateral
    /// @param to address to delegate
    function delegate (address to) external {
        if (msg.sender != owner) 
            revert OnlyApproved();
        IDelegateERC20(address(collateral)).delegate(to);
    }

    // Lender

    /// @notice fill a requested loan as a lender
    /// @param reqID index of request in requests[]
    /// @param loanID index of loan in loans[]
    function clear (uint256 reqID) external returns (uint256 loanID) {
        Request storage req = requests[reqID];


        if (!req.active) 
            revert Deactivated();
        else req.active = false;

        uint256 interest = interestFor(req.amount, req.interest, req.duration);
        uint256 collat = collateralFor(req.amount, req.loanToCollateral);
        uint256 expiration = block.timestamp + req.duration;

        loanID = loans.length;
        loans.push(
            Loan(req, req.amount + interest, collat, expiration, true, msg.sender)
        );
        debt.transferFrom(msg.sender, owner, req.amount);

    }

    /// @notice change 'rollable' status of loan
    /// @param loanID index of loan in loans[]
    /// @return bool new 'rollable' status
    function toggleRoll(uint256 loanID) external returns (bool) {
        Loan storage loan = loans[loanID];

        if (msg.sender != loan.lender)
            revert OnlyApproved();

        loan.rollable = !loan.rollable;
        return loan.rollable;
    }

    /// @notice send collateral to lender upon default
    /// @param loanID index of loan in loans[]
    /// @return uint256 collateral amount
    function defaulted (uint256 loanID) external returns (uint256) {
        Loan memory loan = loans[loanID];
        delete loans[loanID];

        if (block.timestamp <= loan.expiry) 
            revert NoDefault();

        collateral.transfer(loan.lender, loan.collateral);
        return loan.collateral;
    }

    /// @notice approve transfer of loan ownership to new address
    /// @param to address to approve
    /// @param loanID index of loan in loans[]
    function approve (address to, uint256 loanID) external {
        Loan memory loan = loans[loanID];

        if (msg.sender != loan.lender)
            revert OnlyApproved();

        approvals[loanID] = to;
    }

    /// @notice execute approved transfer of loan ownership
    /// @param loanID index of loan in loans[]
    function transfer (uint256 loanID) external {
        if (msg.sender != approvals[loanID])
            revert OnlyApproved();

        approvals[loanID] = address(0);
        loans[loanID].lender = msg.sender;
    }

    // Views

    /// @notice compute collateral needed for loan amount at given loan to collateral ratio
    /// @param amount of collateral tokens
    /// @param loanToCollateral ratio for loan
    function collateralFor(uint256 amount, uint256 loanToCollateral) public pure  returns (uint256) {
        return amount * decimals / loanToCollateral;
    }

    /// @notice compute interest cost on amount for duration at given annualized rate
    /// @param amount of debt tokens
    /// @param rate of interest (annualized)
    /// @param duration of loan in seconds
    /// @return interest as a number of debt tokens
    function interestFor(uint256 amount, uint256 rate, uint256 duration) public pure returns (uint256) {
        uint256 interest = rate * duration / 365 days;
        return amount * interest / decimals;
    }

    /// @notice check if given loan is in default
    /// @param loanID index of loan in loans[]
    /// @return defaulted status
    function isDefaulted(uint256 loanID) external view returns (bool) {
        return block.timestamp > loans[loanID].expiry;
    }

    /// @notice check if given request is active
    /// @param reqID index of request in requests[]
    /// @return active status
    function isActive(uint256 reqID) external view returns (bool) {
        return requests[reqID].active;
    }
}