
// File: contracts/interfaces/PackedUserOperation.sol


pragma solidity ^0.8.28;

/**
 * User Operation struct
 * @param sender                - The sender account of this request.
 * @param nonce                 - Unique value the sender uses to verify it is not a replay.
 * @param initCode              - If set, the account contract will be created by this constructor
 * @param callData              - The method call to execute on this account.
 * @param accountGasLimits      - Packed gas limits for validateUserOp and gas limit passed to the callData method call.
 * @param preVerificationGas    - Gas not calculated by the handleOps method, but added to the gas paid.
 *                                Covers batch overhead.
 * @param gasFees               - packed gas fields maxPriorityFeePerGas and maxFeePerGas - Same as EIP-1559 gas parameters.
 * @param paymasterAndData      - If set, this field holds the paymaster address, verification gas limit, postOp gas limit and paymaster-specific extra data
 *                                The paymaster will pay for the transaction instead of the sender.
 * @param signature             - Sender-verified signature over the entire request, the EntryPoint address and the chain ID.
 */
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

// File: contracts/interfaces/IAccount.sol


pragma solidity ^0.8.28;


interface IAccount {
    /**
     * Validate user's signature and nonce
     * the entryPoint will make the call to the recipient only if this validation call returns successfully.
     * signature failure should be reported by returning SIG_VALIDATION_FAILED (1).
     * This allows making a "simulation call" without a valid signature
     * Other failures (e.g. nonce mismatch, or invalid signature format) should still revert to signal failure.
     *
     * @dev Must validate caller is the entryPoint.
     *      Must validate the signature and nonce
     * @param userOp              - The operation that is about to be executed.
     * @param userOpHash          - Hash of the user's request data. can be used as the basis for signature.
     * @param missingAccountFunds - Missing funds on the account's deposit in the entrypoint.
     *                              This is the minimum amount to transfer to the sender(entryPoint) to be
     *                              able to make the call. The excess is left as a deposit in the entrypoint
     *                              for future calls. Can be withdrawn anytime using "entryPoint.withdrawTo()".
     *                              In case there is a paymaster in the request (or the current deposit is high
     *                              enough), this value will be zero.
     * @return validationData       - Packaged ValidationData structure. use `_packValidationData` and
     *                              `_unpackValidationData` to encode and decode.
     *                              <20-byte> aggregatorOrSigFail - 0 for valid signature, 1 to mark signature failure,
     *                                 otherwise, an address of an "aggregator" contract.
     *                              <6-byte> validUntil - Last timestamp this operation is valid at, or 0 for "indefinitely"
     *                              <6-byte> validAfter - First timestamp this operation is valid
     *                                                    If an account doesn't use time-range, it is enough to
     *                                                    return SIG_VALIDATION_FAILED value (1) for signature failure.
     *                              Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

// File: contracts/interfaces/IAccountExecute.sol


pragma solidity ^0.8.28;


interface IAccountExecute {
    /**
     * Account may implement this execute method.
     * passing this methodSig at the beginning of callData will cause the entryPoint to pass the full UserOp (and hash)
     * to the account.
     * The account should skip the methodSig, and use the callData (and optionally, other UserOp fields)
     *
     * @param userOp              - The operation that was just validated.
     * @param userOpHash          - Hash of the user's request data.
     */
    function executeUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external;
}

// File: contracts/interfaces/IStakeManager.sol


pragma solidity ^0.8.28;

/**
 * Manage deposits and stakes.
 * Deposit is just a balance used to pay for UserOperations (either by a paymaster or an account).
 * Stake is value locked for at least "unstakeDelay" by the staked entity.
 */
interface IStakeManager {
    event Deposited(address indexed account, uint256 totalDeposit);

    event Withdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    // Emitted when stake or unstake delay are modified.
    event StakeLocked(
        address indexed account,
        uint256 totalStaked,
        uint256 unstakeDelaySec
    );

    // Emitted once a stake is scheduled for withdrawal.
    event StakeUnlocked(address indexed account, uint256 withdrawTime);

    event StakeWithdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    /**
     * @param deposit         - The entity's deposit.
     * @param staked          - True if this entity is staked.
     * @param stake           - Actual amount of ether staked for this entity.
     * @param unstakeDelaySec - Minimum delay to withdraw the stake.
     * @param withdrawTime    - First block timestamp where 'withdrawStake' will be callable, or zero if already locked.
     * @dev Sizes were chosen so that deposit fits into one cell (used during handleOp)
     *      and the rest fit into a 2nd cell (used during stake/unstake)
     *      - 112 bit allows for 10^15 eth
     *      - 48 bit for full timestamp
     *      - 32 bit allows 150 years for unstake delay
     */
    struct DepositInfo {
        uint256 deposit;
        bool staked;
        uint112 stake;
        uint32 unstakeDelaySec;
        uint48 withdrawTime;
    }

    // API struct used by getStakeInfo and simulateValidation.
    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }

    /**
     * Get deposit info.
     * @param account - The account to query.
     * @return info   - Full deposit information of given account.
     */
    function getDepositInfo(
        address account
    ) external view returns (DepositInfo memory info);

    /**
     * Get account balance.
     * @param account - The account to query.
     * @return        - The deposit (for gas payment) of the account.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * Add to the deposit of the given account.
     * @param account - The account to add to.
     */
    function depositTo(address account) external payable;

    /**
     * Add to the account's stake - amount and delay
     * any pending unstake is first cancelled.
     * @param unstakeDelaySec - The new lock duration before the deposit can be withdrawn.
     */
    function addStake(uint32 unstakeDelaySec) external payable;

    /**
     * Attempt to unlock the stake.
     * The value can be withdrawn (using withdrawStake) after the unstake delay.
     */
    function unlockStake() external;

    /**
     * Withdraw from the (unlocked) stake.
     * Must first call unlockStake and wait for the unstakeDelay to pass.
     * @param withdrawAddress - The address to send withdrawn value.
     */
    function withdrawStake(address payable withdrawAddress) external;

    /**
     * Withdraw from the deposit.
     * @param withdrawAddress - The address to send withdrawn value.
     * @param withdrawAmount  - The amount to withdraw.
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external;
}

// File: contracts/interfaces/IAggregator.sol


pragma solidity ^0.8.28;


/**
 * Aggregated Signatures validator.
 */
interface IAggregator {
    /**
     * Validate an aggregated signature.
     * Reverts if the aggregated signature does not match the given list of operations.
     * @param userOps   - An array of UserOperations to validate the signature for.
     * @param signature - The aggregated signature.
     */
    function validateSignatures(
        PackedUserOperation[] calldata userOps,
        bytes calldata signature
    ) external;

    /**
     * Validate the signature of a single userOp.
     * This method should be called by bundler after EntryPointSimulation.simulateValidation() returns
     * the aggregator this account uses.
     * First it validates the signature over the userOp. Then it returns data to be used when creating the handleOps.
     * @param userOp        - The userOperation received from the user.
     * @return sigForUserOp - The value to put into the signature field of the userOp when calling handleOps.
     *                        (usually empty, unless account and aggregator support some kind of "multisig".
     */
    function validateUserOpSignature(
        PackedUserOperation calldata userOp
    ) external view returns (bytes memory sigForUserOp);

    /**
     * Aggregate multiple signatures into a single value.
     * This method is called off-chain to calculate the signature to pass with handleOps()
     * bundler MAY use optimized custom code to perform this aggregation.
     * @param userOps              - An array of UserOperations to collect the signatures from.
     * @return aggregatedSignature - The aggregated signature.
     */
    function aggregateSignatures(
        PackedUserOperation[] calldata userOps
    ) external view returns (bytes memory aggregatedSignature);
}

// File: contracts/interfaces/INonceManager.sol


pragma solidity ^0.8.28;

interface INonceManager {

    /**
     * Return the next nonce for this sender.
     * Within a given key, the nonce values are sequenced (starting with zero, and incremented by one on each userop)
     * But UserOp with different keys can come with arbitrary order.
     *
     * @param sender the account address
     * @param key the high 192 bit of the nonce
     * @return nonce a full nonce to pass for next UserOp with this sender.
     */
    function getNonce(address sender, uint192 key)
    external view returns (uint256 nonce);

    /**
     * Manually increment the nonce of the sender.
     * This method is exposed just for completeness..
     * Account does NOT need to call it, neither during validation, nor elsewhere,
     * as the EntryPoint will update the nonce regardless.
     * Possible use-case is call it with various keys to "initialize" their nonces to one, so that future
     * UserOperations will not pay extra for the first transaction with a given key.
     *
     * @param key - the "nonce key" to increment the "nonce sequence" for.
     */
    function incrementNonce(uint192 key) external;
}

// File: contracts/interfaces/ISenderCreator.sol


pragma solidity ^0.8.28;

interface ISenderCreator {
    /**
     * @dev Creates a new sender contract.
     * @return sender Address of the newly created sender contract.
     */
    function createSender(bytes calldata initCode) external returns (address sender);

    /**
     * Use initCallData to initialize an EIP-7702 account.
     * The caller is the EntryPoint contract and it is already verified to be an EIP-7702 account.
     * Note: Can be called multiple times as long as an appropriate initCode is supplied
     *
     * @param sender - the 'sender' EIP-7702 account to be initialized.
     * @param initCallData - the call data to be passed to the sender account call.
     */
    function initEip7702Sender(address sender, bytes calldata initCallData) external;
}

// File: contracts/interfaces/IEntryPoint.sol

/**
 ** Account-Abstraction (EIP-4337) singleton EntryPoint implementation.
 ** Only one instance required on each chain.
 **/

pragma solidity ^0.8.28;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */






interface IEntryPoint is IStakeManager, INonceManager {
    /***
     * An event emitted after each successful request.
     * @param userOpHash    - Unique identifier for the request (hash its entire content, except signature).
     * @param sender        - The account that generates this request.
     * @param paymaster     - If non-null, the paymaster that pays for this request.
     * @param nonce         - The nonce value from the request.
     * @param success       - True if the sender transaction succeeded, false if reverted.
     * @param actualGasCost - Actual amount paid (by account or paymaster) for this UserOperation.
     * @param actualGasUsed - Total gas used by this UserOperation (including preVerification, creation,
     *                        validation and execution).
     */
    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed paymaster,
        uint256 nonce,
        bool success,
        uint256 actualGasCost,
        uint256 actualGasUsed
    );

    /**
     * Account "sender" was deployed.
     * @param userOpHash - The userOp that deployed this account. UserOperationEvent will follow.
     * @param sender     - The account that is deployed
     * @param factory    - The factory used to deploy this account (in the initCode)
     * @param paymaster  - The paymaster used by this UserOp
     */
    event AccountDeployed(
        bytes32 indexed userOpHash,
        address indexed sender,
        address factory,
        address paymaster
    );

    /**
     * An event emitted if the UserOperation "callData" reverted with non-zero length.
     * @param userOpHash   - The request unique identifier.
     * @param sender       - The sender of this request.
     * @param nonce        - The nonce used in the request.
     * @param revertReason - The return bytes from the reverted "callData" call.
     */
    event UserOperationRevertReason(
        bytes32 indexed userOpHash,
        address indexed sender,
        uint256 nonce,
        bytes revertReason
    );

    /**
     * An event emitted if the UserOperation Paymaster's "postOp" call reverted with non-zero length.
     * @param userOpHash   - The request unique identifier.
     * @param sender       - The sender of this request.
     * @param nonce        - The nonce used in the request.
     * @param revertReason - The return bytes from the reverted call to "postOp".
     */
    event PostOpRevertReason(
        bytes32 indexed userOpHash,
        address indexed sender,
        uint256 nonce,
        bytes revertReason
    );

    /**
     * UserOp consumed more than prefund. The UserOperation is reverted, and no refund is made.
     * @param userOpHash   - The request unique identifier.
     * @param sender       - The sender of this request.
     * @param nonce        - The nonce used in the request.
     */
    event UserOperationPrefundTooLow(
        bytes32 indexed userOpHash,
        address indexed sender,
        uint256 nonce
    );

    /**
     * An event emitted by handleOps() and handleAggregatedOps(), before starting the execution loop.
     * Any event emitted before this event, is part of the validation.
     */
    event BeforeExecution();

    /**
     * Signature aggregator used by the following UserOperationEvents within this bundle.
     * @param aggregator - The aggregator used for the following UserOperationEvents.
     */
    event SignatureAggregatorChanged(address indexed aggregator);

    /**
     * A custom revert error of handleOps andhandleAggregatedOps, to identify the offending op.
     * Should be caught in off-chain handleOps/handleAggregatedOps simulation and not happen on-chain.
     * Useful for mitigating DoS attempts against batchers or for troubleshooting of factory/account/paymaster reverts.
     * NOTE: If simulateValidation passes successfully, there should be no reason for handleOps to fail on it.
     * @param opIndex - Index into the array of ops to the failed one (in simulateValidation, this is always zero).
     * @param reason  - Revert reason. The string starts with a unique code "AAmn",
     *                  where "m" is "1" for factory, "2" for account and "3" for paymaster issues,
     *                  so a failure can be attributed to the correct entity.
     */
    error FailedOp(uint256 opIndex, string reason);

    /**
     * A custom revert error of handleOps and handleAggregatedOps, to report a revert by account or paymaster.
     * @param opIndex - Index into the array of ops to the failed one (in simulateValidation, this is always zero).
     * @param reason  - Revert reason. see FailedOp(uint256,string), above
     * @param inner   - data from inner cought revert reason
     * @dev note that inner is truncated to 2048 bytes
     */
    error FailedOpWithRevert(uint256 opIndex, string reason, bytes inner);

    error PostOpReverted(bytes returnData);

    /**
     * Error case when a signature aggregator fails to verify the aggregated signature it had created.
     * @param aggregator The aggregator that failed to verify the signature
     */
    error SignatureValidationFailed(address aggregator);

    // Return value of getSenderAddress.
    error SenderAddressResult(address sender);

    // UserOps handled, per aggregator.
    struct UserOpsPerAggregator {
        PackedUserOperation[] userOps;
        // Aggregator address
        IAggregator aggregator;
        // Aggregated signature
        bytes signature;
    }

    /**
     * Execute a batch of UserOperations.
     * No signature aggregator is used.
     * If any account requires an aggregator (that is, it returned an aggregator when
     * performing simulateValidation), then handleAggregatedOps() must be used instead.
     * @param ops         - The operations to execute.
     * @param beneficiary - The address to receive the fees.
     */
    function handleOps(
        PackedUserOperation[] calldata ops,
        address payable beneficiary
    ) external;

    /**
     * Execute a batch of UserOperation with Aggregators
     * @param opsPerAggregator - The operations to execute, grouped by aggregator (or address(0) for no-aggregator accounts).
     * @param beneficiary      - The address to receive the fees.
     */
    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata opsPerAggregator,
        address payable beneficiary
    ) external;

    /**
     * Generate a request Id - unique identifier for this request.
     * The request ID is a hash over the content of the userOp (except the signature), entrypoint address, chainId and (optionally) 7702 delegate address
     * @param userOp - The user operation to generate the request ID for.
     * @return hash the hash of this UserOperation
     */
    function getUserOpHash(
        PackedUserOperation calldata userOp
    ) external view returns (bytes32);

    /**
     * Gas and return values during simulation.
     * @param preOpGas         - The gas used for validation (including preValidationGas)
     * @param prefund          - The required prefund for this operation
     * @param accountValidationData   - returned validationData from account.
     * @param paymasterValidationData - return validationData from paymaster.
     * @param paymasterContext - Returned by validatePaymasterUserOp (to be passed into postOp)
     */
    struct ReturnInfo {
        uint256 preOpGas;
        uint256 prefund;
        uint256 accountValidationData;
        uint256 paymasterValidationData;
        bytes paymasterContext;
    }

    /**
     * Get counterfactual sender address.
     * Calculate the sender contract address that will be generated by the initCode and salt in the UserOperation.
     * This method always revert, and returns the address in SenderAddressResult error.
     * @notice this method cannot be used for EIP-7702 derived contracts.
     *
     * @param initCode - The constructor code to be passed into the UserOperation.
     */
    function getSenderAddress(bytes memory initCode) external;

    error DelegateAndRevert(bool success, bytes ret);

    /**
     * Helper method for dry-run testing.
     * @dev calling this method, the EntryPoint will make a delegatecall to the given data, and report (via revert) the result.
     *  The method always revert, so is only useful off-chain for dry run calls, in cases where state-override to replace
     *  actual EntryPoint code is less convenient.
     * @param target a target contract to make a delegatecall from entrypoint
     * @param data data to pass to target in a delegatecall
     */
    function delegateAndRevert(address target, bytes calldata data) external;

    /**
     * @notice Retrieves the immutable SenderCreator contract which is responsible for deployment of sender contracts.
     */
    function senderCreator() external view returns (ISenderCreator);
}

// File: contracts/interfaces/IPaymaster.sol


pragma solidity ^0.8.28;


/**
 * The interface exposed by a paymaster contract, who agrees to pay the gas for user's operations.
 * A paymaster must hold a stake to cover the required entrypoint stake and also the gas for the transaction.
 */
interface IPaymaster {
    enum PostOpMode {
        // User op succeeded.
        opSucceeded,
        // User op reverted. Still has to pay for gas.
        opReverted,
        // Only used internally in the EntryPoint (cleanup after postOp reverts). Never calling paymaster with this value
        postOpReverted
    }

    /**
     * Payment validation: check if paymaster agrees to pay.
     * Must verify sender is the entryPoint.
     * Revert to reject this request.
     * Note that bundlers will reject this method if it changes the state, unless the paymaster is trusted (whitelisted).
     * The paymaster pre-pays using its deposit, and receive back a refund after the postOp method returns.
     * @param userOp          - The user operation.
     * @param userOpHash      - Hash of the user's request data.
     * @param maxCost         - The maximum cost of this transaction (based on maximum gas and gas price from userOp).
     * @return context        - Value to send to a postOp. Zero length to signify postOp is not required.
     * @return validationData - Signature and time-range of this operation, encoded the same as the return
     *                          value of validateUserOperation.
     *                          <20-byte> aggregatorOrSigFail - 0 for valid signature, 1 to mark signature failure,
     *                                                    other values are invalid for paymaster.
     *                          <6-byte> validUntil - Last timestamp this operation is valid at, or 0 for "indefinitely"
     *                          <6-byte> validAfter - first timestamp this operation is valid
     *                          Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);

    /**
     * Post-operation handler.
     * Must verify sender is the entryPoint.
     * @param mode          - Enum with the following options:
     *                        opSucceeded - User operation succeeded.
     *                        opReverted  - User op reverted. The paymaster still has to pay for gas.
     *                        postOpReverted - never passed in a call to postOp().
     * @param context       - The context value returned by validatePaymasterUserOp
     * @param actualGasCost - Actual cost of gas used so far (without this postOp call).
     * @param actualUserOpFeePerGas - the gas price this UserOp pays. This value is based on the UserOp's maxFeePerGas
     *                        and maxPriorityFee (and basefee)
     *                        It is not the same as tx.gasprice, which is what the bundler pays.
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external;
}

// File: contracts/core/Helpers.sol


pragma solidity ^0.8.28;

/* solhint-disable no-inline-assembly */


 /*
  * For simulation purposes, validateUserOp (and validatePaymasterUserOp)
  * must return this value in case of signature failure, instead of revert.
  */
uint256 constant SIG_VALIDATION_FAILED = 1;


/*
 * For simulation purposes, validateUserOp (and validatePaymasterUserOp)
 * return this value on success.
 */
uint256 constant SIG_VALIDATION_SUCCESS = 0;


/**
 * Returned data from validateUserOp.
 * validateUserOp returns a uint256, which is created by `_packedValidationData` and
 * parsed by `_parseValidationData`.
 * @param aggregator  - address(0) - The account validated the signature by itself.
 *                      address(1) - The account failed to validate the signature.
 *                      otherwise - This is an address of a signature aggregator that must
 *                                  be used to validate the signature.
 * @param validAfter  - This UserOp is valid only after this timestamp.
 * @param validUntil - Last timestamp this operation is valid at, or 0 for "indefinitely".
 */
struct ValidationData {
    address aggregator;
    uint48 validAfter;
    uint48 validUntil;
}

/**
 * Extract aggregator/sigFailed, validAfter, validUntil.
 * Also convert zero validUntil to type(uint48).max.
 * @param validationData - The packed validation data.
 * @return data - The unpacked in-memory validation data.
 */
function _parseValidationData(
    uint256 validationData
) pure returns (ValidationData memory data) {
    address aggregator = address(uint160(validationData));
    uint48 validUntil = uint48(validationData >> 160);
    if (validUntil == 0) {
        validUntil = type(uint48).max;
    }
    uint48 validAfter = uint48(validationData >> (48 + 160));
    return ValidationData(aggregator, validAfter, validUntil);
}

/**
 * Helper to pack the return value for validateUserOp.
 * @param data - The ValidationData to pack.
 * @return the packed validation data.
 */
function _packValidationData(
    ValidationData memory data
) pure returns (uint256) {
    return
        uint160(data.aggregator) |
        (uint256(data.validUntil) << 160) |
        (uint256(data.validAfter) << (160 + 48));
}

/**
 * Helper to pack the return value for validateUserOp, when not using an aggregator.
 * @param sigFailed  - True for signature failure, false for success.
 * @param validUntil - Last timestamp this operation is valid at, or 0 for "indefinitely".
 * @param validAfter - First timestamp this UserOperation is valid.
 * @return the packed validation data.
 */
function _packValidationData(
    bool sigFailed,
    uint48 validUntil,
    uint48 validAfter
) pure returns (uint256) {
    return
        (sigFailed ?  SIG_VALIDATION_FAILED : SIG_VALIDATION_SUCCESS) |
        (uint256(validUntil) << 160) |
        (uint256(validAfter) << (160 + 48));
}

/**
 * keccak function over calldata.
 * @dev copy calldata into memory, do keccak and drop allocated memory. Strangely, this is more efficient than letting solidity do it.
 *
 * @param data - the calldata bytes array to perform keccak on.
 * @return ret - the keccak hash of the 'data' array.
 */
    function calldataKeccak(bytes calldata data) pure returns (bytes32 ret) {
        assembly ("memory-safe") {
            let mem := mload(0x40)
            let len := data.length
            calldatacopy(mem, data.offset, len)
            ret := keccak256(mem, len)
        }
    }


/**
 * The minimum of two numbers.
 * @param a - First number.
 * @param b - Second number.
 * @return - the minimum value.
 */
    function min(uint256 a, uint256 b) pure returns (uint256) {
        return a < b ? a : b;
    }

/**
 * standard solidity memory allocation finalization.
 * copied from solidity generated code
 * @param memPointer - The current memory pointer
 * @param allocationSize - Bytes allocated from memPointer.
 */
    function finalizeAllocation(uint256 memPointer, uint256 allocationSize) pure {

        assembly ("memory-safe"){
            finalize_allocation(memPointer, allocationSize)

            function finalize_allocation(memPtr, size) {
                let newFreePtr := add(memPtr, round_up_to_mul_of_32(size))
                mstore(64, newFreePtr)
            }

            function round_up_to_mul_of_32(value) -> result {
                result := and(add(value, 31), not(31))
            }
        }
    }

// File: contracts/core/UserOperationLib.sol


pragma solidity ^0.8.28;

/* solhint-disable no-inline-assembly */



/**
 * Utility functions helpful when working with UserOperation structs.
 */
library UserOperationLib {

    uint256 public constant PAYMASTER_VALIDATION_GAS_OFFSET = 20;
    uint256 public constant PAYMASTER_POSTOP_GAS_OFFSET = 36;
    uint256 public constant PAYMASTER_DATA_OFFSET = 52;

    /**
     * Relayer/block builder might submit the TX with higher priorityFee,
     * but the user should not pay above what he signed for.
     * @param userOp - The user operation data.
     */
    function gasPrice(
        PackedUserOperation calldata userOp
    ) internal view returns (uint256) {
        unchecked {
            (uint256 maxPriorityFeePerGas, uint256 maxFeePerGas) = unpackUints(userOp.gasFees);
            return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
        }
    }

    bytes32 internal constant PACKED_USEROP_TYPEHASH =
    keccak256(
        "PackedUserOperation(address sender,uint256 nonce,bytes initCode,bytes callData,bytes32 accountGasLimits,uint256 preVerificationGas,bytes32 gasFees,bytes paymasterAndData)"
    );

    /**
     * Pack the user operation data into bytes for hashing.
     * @param userOp - The user operation data.
     * @param overrideInitCodeHash - If set, encode this instead of the initCode field in the userOp.
     */
    function encode(
        PackedUserOperation calldata userOp,
        bytes32 overrideInitCodeHash
    ) internal pure returns (bytes memory ret) {
        address sender = userOp.sender;
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = overrideInitCodeHash != 0 ? overrideInitCodeHash : calldataKeccak(userOp.initCode);
        bytes32 hashCallData = calldataKeccak(userOp.callData);
        bytes32 accountGasLimits = userOp.accountGasLimits;
        uint256 preVerificationGas = userOp.preVerificationGas;
        bytes32 gasFees = userOp.gasFees;
        bytes32 hashPaymasterAndData = calldataKeccak(userOp.paymasterAndData);

        return abi.encode(
            UserOperationLib.PACKED_USEROP_TYPEHASH,
            sender, nonce,
            hashInitCode, hashCallData,
            accountGasLimits, preVerificationGas, gasFees,
            hashPaymasterAndData
        );
    }

    function unpackUints(
        bytes32 packed
    ) internal pure returns (uint256 high128, uint256 low128) {
        return (unpackHigh128(packed), unpackLow128(packed));
    }

    // Unpack just the high 128-bits from a packed value
    function unpackHigh128(bytes32 packed) internal pure returns (uint256) {
        return uint256(packed) >> 128;
    }

    // Unpack just the low 128-bits from a packed value
    function unpackLow128(bytes32 packed) internal pure returns (uint256) {
        return uint128(uint256(packed));
    }

    function unpackMaxPriorityFeePerGas(PackedUserOperation calldata userOp)
    internal pure returns (uint256) {
        return unpackHigh128(userOp.gasFees);
    }

    function unpackMaxFeePerGas(PackedUserOperation calldata userOp)
    internal pure returns (uint256) {
        return unpackLow128(userOp.gasFees);
    }

    function unpackVerificationGasLimit(PackedUserOperation calldata userOp)
    internal pure returns (uint256) {
        return unpackHigh128(userOp.accountGasLimits);
    }

    function unpackCallGasLimit(PackedUserOperation calldata userOp)
    internal pure returns (uint256) {
        return unpackLow128(userOp.accountGasLimits);
    }

    function unpackPaymasterVerificationGasLimit(PackedUserOperation calldata userOp)
    internal pure returns (uint256) {
        return uint128(bytes16(userOp.paymasterAndData[PAYMASTER_VALIDATION_GAS_OFFSET : PAYMASTER_POSTOP_GAS_OFFSET]));
    }

    function unpackPostOpGasLimit(PackedUserOperation calldata userOp)
    internal pure returns (uint256) {
        return uint128(bytes16(userOp.paymasterAndData[PAYMASTER_POSTOP_GAS_OFFSET : PAYMASTER_DATA_OFFSET]));
    }

    function unpackPaymasterStaticFields(
        bytes calldata paymasterAndData
    ) internal pure returns (address paymaster, uint256 validationGasLimit, uint256 postOpGasLimit) {
        return (
            address(bytes20(paymasterAndData[: PAYMASTER_VALIDATION_GAS_OFFSET])),
            uint128(bytes16(paymasterAndData[PAYMASTER_VALIDATION_GAS_OFFSET : PAYMASTER_POSTOP_GAS_OFFSET])),
            uint128(bytes16(paymasterAndData[PAYMASTER_POSTOP_GAS_OFFSET : PAYMASTER_DATA_OFFSET]))
        );
    }

    /**
     * Hash the user operation data.
     * @param userOp - The user operation data.
     * @param overrideInitCodeHash - If set, the initCode hash will be replaced with this value just for UserOp hashing.
     */
    function hash(
        PackedUserOperation calldata userOp,
        bytes32 overrideInitCodeHash
    ) internal pure returns (bytes32) {
        return keccak256(encode(userOp, overrideInitCodeHash));
    }
}

// File: contracts/core/StakeManager.sol


pragma solidity ^0.8.28;


/* solhint-disable avoid-low-level-calls */
/* solhint-disable not-rely-on-time */

/**
 * Manage deposits and stakes.
 * Deposit is just a balance used to pay for UserOperations (either by a paymaster or an account).
 * Stake is value locked for at least "unstakeDelay" by a paymaster.
 */
abstract contract StakeManager is IStakeManager {
    /// maps paymaster to their deposits and stakes
    mapping(address => DepositInfo) private deposits;

    /// @inheritdoc IStakeManager
    function getDepositInfo(
        address account
    ) external view returns (DepositInfo memory info) {
        return deposits[account];
    }

    /**
     * Internal method to return just the stake info.
     * @param addr - The account to query.
     */
    function _getStakeInfo(
        address addr
    ) internal view returns (StakeInfo memory info) {
        DepositInfo storage depositInfo = deposits[addr];
        info.stake = depositInfo.stake;
        info.unstakeDelaySec = depositInfo.unstakeDelaySec;
    }

    /// @inheritdoc IStakeManager
    function balanceOf(address account) public view returns (uint256) {
        return deposits[account].deposit;
    }

    receive() external payable {
        depositTo(msg.sender);
    }


    /**
     * Increments an account's deposit.
     * @param account - The account to increment.
     * @param amount  - The amount to increment by.
     * @return the updated deposit of this account
     */
    function _incrementDeposit(address account, uint256 amount) internal returns (uint256) {
        unchecked {
            DepositInfo storage info = deposits[account];
            uint256 newAmount = info.deposit + amount;
            info.deposit = newAmount;
            return newAmount;
        }
    }

    /**
     * Try to decrement the account's deposit.
     * @param account - The account to decrement.
     * @param amount  - The amount to decrement by.
     * @return true if the decrement succeeded (that is, previous balance was at least that amount)
     */
    function _tryDecrementDeposit(address account, uint256 amount) internal returns(bool) {
        unchecked {
            DepositInfo storage info = deposits[account];
            uint256 currentDeposit = info.deposit;
            if (currentDeposit < amount) {
                return false;
            }
            info.deposit = currentDeposit - amount;
            return true;
        }
    }

    /// @inheritdoc IStakeManager
    function depositTo(address account) public virtual payable {
        uint256 newDeposit = _incrementDeposit(account, msg.value);
        emit Deposited(account, newDeposit);
    }

    /// @inheritdoc IStakeManager
    function addStake(uint32 unstakeDelaySec) external payable {
        DepositInfo storage info = deposits[msg.sender];
        require(unstakeDelaySec > 0, "must specify unstake delay");
        require(
            unstakeDelaySec >= info.unstakeDelaySec,
            "cannot decrease unstake time"
        );
        uint256 stake = info.stake + msg.value;
        require(stake > 0, "no stake specified");
        require(stake <= type(uint112).max, "stake overflow");
        deposits[msg.sender] = DepositInfo(
            info.deposit,
            true,
            uint112(stake),
            unstakeDelaySec,
            0
        );
        emit StakeLocked(msg.sender, stake, unstakeDelaySec);
    }

    /// @inheritdoc IStakeManager
    function unlockStake() external {
        DepositInfo storage info = deposits[msg.sender];
        require(info.unstakeDelaySec != 0, "not staked");
        require(info.staked, "already unstaking");
        uint48 withdrawTime = uint48(block.timestamp) + info.unstakeDelaySec;
        info.withdrawTime = withdrawTime;
        info.staked = false;
        emit StakeUnlocked(msg.sender, withdrawTime);
    }

    /// @inheritdoc IStakeManager
    function withdrawStake(address payable withdrawAddress) external {
        DepositInfo storage info = deposits[msg.sender];
        uint256 stake = info.stake;
        require(stake > 0, "No stake to withdraw");
        require(info.withdrawTime > 0, "must call unlockStake() first");
        require(
            info.withdrawTime <= block.timestamp,
            "Stake withdrawal is not due"
        );
        info.unstakeDelaySec = 0;
        info.withdrawTime = 0;
        info.stake = 0;
        emit StakeWithdrawn(msg.sender, withdrawAddress, stake);
        (bool success,) = withdrawAddress.call{value: stake}("");
        require(success, "failed to withdraw stake");
    }

    /// @inheritdoc IStakeManager
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external {
        DepositInfo storage info = deposits[msg.sender];
        uint256 currentDeposit = info.deposit;
        require(withdrawAmount <= currentDeposit, "Withdraw amount too large");
        info.deposit = currentDeposit - withdrawAmount;
        emit Withdrawn(msg.sender, withdrawAddress, withdrawAmount);
        (bool success,) = withdrawAddress.call{value: withdrawAmount}("");
        require(success, "failed to withdraw");
    }
}

// File: contracts/core/NonceManager.sol


pragma solidity ^0.8.28;


/**
 * nonce management functionality
 */
abstract contract NonceManager is INonceManager {

    /**
     * The next valid sequence number for a given nonce key.
     */
    mapping(address => mapping(uint192 => uint256)) public nonceSequenceNumber;

    /// @inheritdoc INonceManager
    function getNonce(address sender, uint192 key)
    public view override returns (uint256 nonce) {
        return nonceSequenceNumber[sender][key] | (uint256(key) << 64);
    }

    /// @inheritdoc INonceManager
    function incrementNonce(uint192 key) external override {
        nonceSequenceNumber[msg.sender][key]++;
    }

    /**
     * validate nonce uniqueness for this account.
     * called just after validateUserOp()
     * @return true if the nonce was incremented successfully.
     *         false if the current nonce doesn't match the given one.
     */
    function _validateAndUpdateNonce(address sender, uint256 nonce) internal returns (bool) {

        uint192 key = uint192(nonce >> 64);
        uint64 seq = uint64(nonce);
        return nonceSequenceNumber[sender][key]++ == seq;
    }

}

// File: contracts/utils/Exec.sol


pragma solidity ^0.8.28;

// solhint-disable no-inline-assembly

/**
 * Utility functions helpful when making different kinds of contract calls in Solidity.
 */
library Exec {

    function call(
        address to,
        uint256 value,
        bytes memory data,
        uint256 txGas
    ) internal returns (bool success) {
        assembly ("memory-safe") {
            success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function staticcall(
        address to,
        bytes memory data,
        uint256 txGas
    ) internal view returns (bool success) {
        assembly ("memory-safe") {
            success := staticcall(txGas, to, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function delegateCall(
        address to,
        bytes memory data,
        uint256 txGas
    ) internal returns (bool success) {
        assembly ("memory-safe") {
            success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
        }
    }

    // get returned data from last call or delegateCall
    // maxLen - maximum length of data to return, or zero, for the full length
    function getReturnData(uint256 maxLen) internal pure returns (bytes memory returnData) {
        assembly ("memory-safe") {
            let len := returndatasize()
            if gt(maxLen,0) {
                if gt(len, maxLen) {
                    len := maxLen
                }
            }
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, add(len, 0x20)))
            mstore(ptr, len)
            returndatacopy(add(ptr, 0x20), 0, len)
            returnData := ptr
        }
    }

    // revert with explicit byte array (probably reverted info from call)
    function revertWithData(bytes memory returnData) internal pure {
        assembly ("memory-safe") {
            revert(add(returnData, 32), mload(returnData))
        }
    }

    // Propagate revert data from last call
    function revertWithReturnData() internal pure {
        revertWithData(getReturnData(0));
    }
}

// File: contracts/core/SenderCreator.sol


pragma solidity ^0.8.28;
/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */




/**
 * Helper contract for EntryPoint, to call userOp.initCode from a "neutral" address,
 * which is explicitly not the entryPoint itself.
 */
contract SenderCreator is ISenderCreator {
    address public immutable entryPoint;

    constructor(){
        entryPoint = msg.sender;
    }

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Call the "initCode" factory to create and return the sender account address.
     * @param initCode - The initCode value from a UserOp. contains 20 bytes of factory address,
     *                   followed by calldata.
     * @return sender  - The returned address of the created account, or zero address on failure.
     */
    function createSender(
        bytes calldata initCode
    ) external returns (address sender) {
        require(msg.sender == entryPoint, "AA97 should call from EntryPoint");
        address factory = address(bytes20(initCode[0 : 20]));

        bytes memory initCallData = initCode[20 :];
        bool success;
        assembly ("memory-safe") {
            success := call(
                gas(),
                factory,
                0,
                add(initCallData, 0x20),
                mload(initCallData),
                0,
                32
            )
            if success {
                sender := mload(0)
            }
        }
    }

    /// @inheritdoc ISenderCreator
    function initEip7702Sender(
        address sender,
        bytes memory initCallData
    ) external {
        require(msg.sender == entryPoint, "AA97 should call from EntryPoint");
        bool success;
        assembly ("memory-safe") {
            success := call(
                gas(),
                sender,
                0,
                add(initCallData, 0x20),
                mload(initCallData),
                0,
                0
            )
        }
        if (!success) {
            bytes memory result = Exec.getReturnData(REVERT_REASON_MAX_LEN);
            revert IEntryPoint.FailedOpWithRevert(0, "AA13 EIP7702 sender init failed", result);
        }
    }
}

// File: contracts/core/Eip7702Support.sol

pragma solidity ^0.8.28;

// solhint-disable no-inline-assembly



library Eip7702Support {

    // EIP-7702 code prefix before delegate address.
    bytes3 internal constant EIP7702_PREFIX = 0xef0100;

    // EIP-7702 initCode marker, to specify this account is EIP-7702.
    bytes2 internal constant INITCODE_EIP7702_MARKER = 0x7702;

    using UserOperationLib for PackedUserOperation;

    /**
     * Get the alternative 'InitCodeHash' value for the UserOp hash calculation when using EIP-7702.
     *
     * @param userOp - the UserOperation to for the 'InitCodeHash' calculation.
     * @return the 'InitCodeHash' value.
     */
    function _getEip7702InitCodeHashOverride(PackedUserOperation calldata userOp) internal view returns (bytes32) {
        bytes calldata initCode = userOp.initCode;
        if (!_isEip7702InitCode(initCode)) {
            return 0;
        }
        address delegate = _getEip7702Delegate(userOp.sender);
        if (initCode.length <= 20)
            return keccak256(abi.encodePacked(delegate));
        else
            return keccak256(abi.encodePacked(delegate, initCode[20 :]));
    }

    /**
     * Check if this 'initCode' is actually an EIP-7702 authorization.
     * This is indicated by 'initCode' that starts with INITCODE_EIP7702_MARKER.
     *
     * @param initCode - the 'initCode' to check.
     * @return true if the 'initCode' is EIP-7702 authorization, false otherwise.
     */
    function _isEip7702InitCode(bytes calldata initCode) internal pure returns (bool) {

        if (initCode.length < 2) {
            return false;
        }
        bytes20 initCodeStart;
        // non-empty calldata bytes are always zero-padded to 32-bytes, so can be safely casted to "bytes20"
        assembly ("memory-safe") {
            initCodeStart := calldataload(initCode.offset)
        }
        // make sure first 20 bytes of initCode are "0x7702" (padded with zeros)
        return initCodeStart == bytes20(INITCODE_EIP7702_MARKER);
    }

    /**
     * Get the EIP-7702 delegate from contract code.
     * Must only be used if _isEip7702InitCode(initCode) is true.
     *
     * @param sender - the EIP-7702 'sender' account to get the delegated contract code address.
     * @return the address of the EIP-7702 authorized contract.
     */
    function _getEip7702Delegate(address sender) internal view returns (address) {

        bytes32 senderCode;

        assembly ("memory-safe") {
            extcodecopy(sender, 0, 0, 23)
            senderCode := mload(0)
        }
        // To be a valid EIP-7702 delegate, the first 3 bytes are EIP7702_PREFIX
        // followed by the delegate address
        if (bytes3(senderCode) != EIP7702_PREFIX) {
            // instead of just "not an EIP-7702 delegate", if some info.
            require(sender.code.length > 0, "sender has no code");
            revert("not an EIP-7702 delegate");
        }
        return address(bytes20(senderCode << 24));
    }
}

// File: @openzeppelin/contracts/utils/TransientSlot.sol


// OpenZeppelin Contracts (last updated v5.3.0) (utils/TransientSlot.sol)
// This file was procedurally generated from scripts/generate/templates/TransientSlot.js.

pragma solidity ^0.8.24;

/**
 * @dev Library for reading and writing value-types to specific transient storage slots.
 *
 * Transient slots are often used to store temporary values that are removed after the current transaction.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 *  * Example reading and writing values using transient storage:
 * ```solidity
 * contract Lock {
 *     using TransientSlot for *;
 *
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _LOCK_SLOT = 0xf4678858b2b588224636b8522b729e7722d32fc491da849ed75b3fdf3c84f542;
 *
 *     modifier locked() {
 *         require(!_LOCK_SLOT.asBoolean().tload());
 *
 *         _LOCK_SLOT.asBoolean().tstore(true);
 *         _;
 *         _LOCK_SLOT.asBoolean().tstore(false);
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library TransientSlot {
    /**
     * @dev UDVT that represents a slot holding an address.
     */
    type AddressSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a AddressSlot.
     */
    function asAddress(bytes32 slot) internal pure returns (AddressSlot) {
        return AddressSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a bool.
     */
    type BooleanSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a BooleanSlot.
     */
    function asBoolean(bytes32 slot) internal pure returns (BooleanSlot) {
        return BooleanSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a bytes32.
     */
    type Bytes32Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Bytes32Slot.
     */
    function asBytes32(bytes32 slot) internal pure returns (Bytes32Slot) {
        return Bytes32Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a uint256.
     */
    type Uint256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Uint256Slot.
     */
    function asUint256(bytes32 slot) internal pure returns (Uint256Slot) {
        return Uint256Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a int256.
     */
    type Int256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Int256Slot.
     */
    function asInt256(bytes32 slot) internal pure returns (Int256Slot) {
        return Int256Slot.wrap(slot);
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(AddressSlot slot) internal view returns (address value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(AddressSlot slot, address value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(BooleanSlot slot) internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(BooleanSlot slot, bool value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Bytes32Slot slot) internal view returns (bytes32 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Bytes32Slot slot, bytes32 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Uint256Slot slot) internal view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Uint256Slot slot, uint256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Int256Slot slot) internal view returns (int256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Int256Slot slot, int256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }
}

// File: @openzeppelin/contracts/utils/ReentrancyGuardTransient.sol


// OpenZeppelin Contracts (last updated v5.3.0) (utils/ReentrancyGuardTransient.sol)

pragma solidity ^0.8.24;


/**
 * @dev Variant of {ReentrancyGuard} that uses transient storage.
 *
 * NOTE: This variant only works on networks where EIP-1153 is available.
 *
 * _Available since v5.1._
 */
abstract contract ReentrancyGuardTransient {
    using TransientSlot for *;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, REENTRANCY_GUARD_STORAGE.asBoolean().tload() will be false
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        REENTRANCY_GUARD_STORAGE.asBoolean().tstore(true);
    }

    function _nonReentrantAfter() private {
        REENTRANCY_GUARD_STORAGE.asBoolean().tstore(false);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return REENTRANCY_GUARD_STORAGE.asBoolean().tload();
    }
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/utils/introspection/ERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;


/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// File: @openzeppelin/contracts/utils/math/Math.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// File: @openzeppelin/contracts/utils/math/SignedMath.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// File: @openzeppelin/contracts/utils/Strings.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;



/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// File: @openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MessageHashUtils.sol)

pragma solidity ^0.8.20;


/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[EIP 191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing an arbitrary `message` with
     * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return
            keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x00` (data with intended validator).
     *
     * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
     * `validator` address. Then hashing the result.
     *
     * See {ECDSA-recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}

// File: @openzeppelin/contracts/utils/StorageSlot.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// File: @openzeppelin/contracts/utils/ShortStrings.sol


// OpenZeppelin Contracts (last updated v5.3.0) (utils/ShortStrings.sol)

pragma solidity ^0.8.20;


// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
    // Used as an identifier for strings longer than 31 bytes.
    bytes32 private constant FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        assembly ("memory-safe") {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev Decode a string that was encoded to `ShortString` or written to storage using {toShortStringWithFallback}.
     */
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev Return the length of a string that was encoded to `ShortString` or written to storage using
     * {toShortStringWithFallback}.
     *
     * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
     * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
     */
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}

// File: @openzeppelin/contracts/interfaces/IERC5267.sol


// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC5267.sol)

pragma solidity >=0.4.16;

interface IERC5267 {
    /**
     * @dev MAY be emitted to signal that the domain could have changed.
     */
    event EIP712DomainChanged();

    /**
     * @dev returns the fields and values that describe the domain separator used by this contract for EIP-712
     * signature.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}

// File: @openzeppelin/contracts/utils/cryptography/EIP712.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.20;




/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP-712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP-712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * NOTE: In the upgradeable version of this contract, the cached values will correspond to the address, and the domain
 * separator of the implementation contract. This will cause the {_domainSeparatorV4} function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable
 */
abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;
    ShortString private immutable _version;
    // slither-disable-next-line constable-states
    string private _nameFallback;
    // slither-disable-next-line constable-states
    string private _versionFallback;

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP-712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /// @inheritdoc IERC5267
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            _EIP712Name(),
            _EIP712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /**
     * @dev The name parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _name which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Name() internal view returns (string memory) {
        return _name.toStringWithFallback(_nameFallback);
    }

    /**
     * @dev The version parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _version which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Version() internal view returns (string memory) {
        return _version.toStringWithFallback(_versionFallback);
    }
}

// File: contracts/core/EntryPoint.sol


pragma solidity ^0.8.28;
/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */

/**
 * Account-Abstraction (EIP-4337) singleton EntryPoint v0.8 implementation.
 * Only one instance required on each chain.
 * @custom:security-contact https://bounty.ethereum.org
 */
contract EntryPoint_flat is IEntryPoint, StakeManager, NonceManager, ReentrancyGuardTransient, ERC165, EIP712 {

    using UserOperationLib for PackedUserOperation;

    /**
     * internal-use constants
     */

    // allow some slack for future gas price changes.
    uint256 private constant INNER_GAS_OVERHEAD = 10000;

    // Marker for inner call revert on out of gas
    bytes32 private constant INNER_OUT_OF_GAS = hex"deaddead";
    bytes32 private constant INNER_REVERT_LOW_PREFUND = hex"deadaa51";

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;
    // Penalty charged for either unused execution gas or postOp gas
    uint256 private constant UNUSED_GAS_PENALTY_PERCENT = 10;
    // Threshold below which no penalty would be charged
    uint256 private constant PENALTY_GAS_THRESHOLD = 40000;

    SenderCreator private immutable _senderCreator = new SenderCreator();

    string constant internal DOMAIN_NAME = "ERC4337";
    string constant internal DOMAIN_VERSION = "1";

    constructor() EIP712(DOMAIN_NAME, DOMAIN_VERSION)  {
    }

    /// @inheritdoc IEntryPoint
    function handleOps(
        PackedUserOperation[] calldata ops,
        address payable beneficiary
    ) external nonReentrant {
        uint256 opslen = ops.length;
        UserOpInfo[] memory opInfos = new UserOpInfo[](opslen);
        unchecked {
            _iterateValidationPhase(ops, opInfos, address(0), 0);

            uint256 collected = 0;
            emit BeforeExecution();

            for (uint256 i = 0; i < opslen; i++) {
                collected += _executeUserOp(i, ops[i], opInfos[i]);
            }

            _compensate(beneficiary, collected);
        }
    }

    /// @inheritdoc IEntryPoint
    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata opsPerAggregator,
        address payable beneficiary
    ) external nonReentrant {

        unchecked {
            uint256 opasLen = opsPerAggregator.length;
            uint256 totalOps = 0;
            for (uint256 i = 0; i < opasLen; i++) {
                UserOpsPerAggregator calldata opa = opsPerAggregator[i];
                PackedUserOperation[] calldata ops = opa.userOps;
                IAggregator aggregator = opa.aggregator;

                // address(1) is special marker of "signature error"
                require(
                    address(aggregator) != address(1),
                    SignatureValidationFailed(address(aggregator))
                );

                if (address(aggregator) != address(0)) {
                    // solhint-disable-next-line no-empty-blocks
                    try aggregator.validateSignatures(ops, opa.signature) {} catch {
                        revert SignatureValidationFailed(address(aggregator));
                    }
                }

                totalOps += ops.length;
            }

            UserOpInfo[] memory opInfos = new UserOpInfo[](totalOps);

            uint256 opIndex = 0;
            for (uint256 a = 0; a < opasLen; a++) {
                UserOpsPerAggregator calldata opa = opsPerAggregator[a];
                PackedUserOperation[] calldata ops = opa.userOps;
                IAggregator aggregator = opa.aggregator;

                opIndex += _iterateValidationPhase(ops, opInfos, address(aggregator), opIndex);
            }

            emit BeforeExecution();

            uint256 collected = 0;
            opIndex = 0;
            for (uint256 a = 0; a < opasLen; a++) {
                UserOpsPerAggregator calldata opa = opsPerAggregator[a];
                emit SignatureAggregatorChanged(address(opa.aggregator));
                PackedUserOperation[] calldata ops = opa.userOps;
                uint256 opslen = ops.length;

                for (uint256 i = 0; i < opslen; i++) {
                    collected += _executeUserOp(opIndex, ops[i], opInfos[opIndex]);
                    opIndex++;
                }
            }

            _compensate(beneficiary, collected);
        }
    }

    /// @inheritdoc IEntryPoint
    function getUserOpHash(
        PackedUserOperation calldata userOp
    ) public view returns (bytes32) {
        bytes32 overrideInitCodeHash = Eip7702Support._getEip7702InitCodeHashOverride(userOp);
        return
            MessageHashUtils.toTypedDataHash(getDomainSeparatorV4(), userOp.hash(overrideInitCodeHash));
    }

    /// @inheritdoc IEntryPoint
    function getSenderAddress(bytes calldata initCode) external {
        address sender = senderCreator().createSender(initCode);
        revert SenderAddressResult(sender);
    }

    /// @inheritdoc IEntryPoint
    function senderCreator() public view virtual returns (ISenderCreator) {
        return _senderCreator;
    }

    /// @inheritdoc IEntryPoint
    function delegateAndRevert(address target, bytes calldata data) external {
        (bool success, bytes memory ret) = target.delegatecall(data);
        revert DelegateAndRevert(success, ret);
    }

    function getPackedUserOpTypeHash() external pure returns (bytes32) {
        return UserOperationLib.PACKED_USEROP_TYPEHASH;
    }

    function getDomainSeparatorV4() public virtual view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // note: solidity "type(IEntryPoint).interfaceId" is without inherited methods but we want to check everything
        return interfaceId == (type(IEntryPoint).interfaceId ^ type(IStakeManager).interfaceId ^ type(INonceManager).interfaceId) ||
        interfaceId == type(IEntryPoint).interfaceId ||
        interfaceId == type(IStakeManager).interfaceId ||
        interfaceId == type(INonceManager).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * Compensate the caller's beneficiary address with the collected fees of all UserOperations.
     * @param beneficiary - The address to receive the fees.
     * @param amount      - Amount to transfer.
     */
    function _compensate(address payable beneficiary, uint256 amount) internal virtual {
        require(beneficiary != address(0), "AA90 invalid beneficiary");
        (bool success,) = beneficiary.call{value: amount}("");
        require(success, "AA91 failed send to beneficiary");
    }

    /**
     * Execute a user operation.
     * @param opIndex    - Index into the opInfo array.
     * @param userOp     - The userOp to execute.
     * @param opInfo     - The opInfo filled by validatePrepayment for this userOp.
     * @return collected - The total amount this userOp paid.
     */
    function _executeUserOp(
        uint256 opIndex,
        PackedUserOperation calldata userOp,
        UserOpInfo memory opInfo
    )
    internal virtual
    returns (uint256 collected) {
        uint256 preGas = gasleft();
        bytes memory context = _getMemoryBytesFromOffset(opInfo.contextOffset);
        bool success;
        {
            uint256 saveFreePtr = _getFreePtr();
            bytes calldata callData = userOp.callData;
            bytes memory innerCall;
            bytes4 methodSig;
            assembly ("memory-safe") {
                let len := callData.length
                if gt(len, 3) {
                    methodSig := calldataload(callData.offset)
                }
            }
            if (methodSig == IAccountExecute.executeUserOp.selector) {
                bytes memory executeUserOp = abi.encodeCall(IAccountExecute.executeUserOp, (userOp, opInfo.userOpHash));
                innerCall = abi.encodeCall(this.innerHandleOp, (executeUserOp, opInfo, context));
            } else
            {
                innerCall = abi.encodeCall(this.innerHandleOp, (callData, opInfo, context));
            }
            assembly ("memory-safe") {
                success := call(gas(), address(), 0, add(innerCall, 0x20), mload(innerCall), 0, 32)
                collected := mload(0)
            }
            _restoreFreePtr(saveFreePtr);
        }
        if (!success) {
            bytes32 innerRevertCode;
            assembly ("memory-safe") {
                let len := returndatasize()
                if eq(32, len) {
                    returndatacopy(0, 0, 32)
                    innerRevertCode := mload(0)
                }
            }
            if (innerRevertCode == INNER_OUT_OF_GAS) {
                // handleOps was called with gas limit too low. abort entire bundle.
                // can only be caused by bundler (leaving not enough gas for inner call)
                revert FailedOp(opIndex, "AA95 out of gas");
            } else if (innerRevertCode == INNER_REVERT_LOW_PREFUND) {
                // innerCall reverted on prefund too low. treat entire prefund as "gas cost"
                uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
                uint256 actualGasCost = opInfo.prefund;
                _emitPrefundTooLow(opInfo);
                _emitUserOperationEvent(opInfo, false, actualGasCost, actualGas);
                collected = actualGasCost;
            } else {
                uint256 freePtr = _getFreePtr();
                emit PostOpRevertReason(
                    opInfo.userOpHash,
                    opInfo.mUserOp.sender,
                    opInfo.mUserOp.nonce,
                    Exec.getReturnData(REVERT_REASON_MAX_LEN)
                );
                _restoreFreePtr(freePtr);

                uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
                collected = _postExecution(
                    IPaymaster.PostOpMode.postOpReverted,
                    opInfo,
                    context,
                    actualGas
                );
            }
        }
    }

    /**
     * Emit the UserOperationEvent for the given UserOperation.
     *
     * @param opInfo         - The details of the current UserOperation.
     * @param success        - Whether the execution of the UserOperation has succeeded or not.
     * @param actualGasCost  - The actual cost of the consumed gas charged from the sender or the paymaster.
     * @param actualGas      - The actual amount of gas used.
     */
    function _emitUserOperationEvent(UserOpInfo memory opInfo, bool success, uint256 actualGasCost, uint256 actualGas) internal virtual {
        emit UserOperationEvent(
            opInfo.userOpHash,
            opInfo.mUserOp.sender,
            opInfo.mUserOp.paymaster,
            opInfo.mUserOp.nonce,
            success,
            actualGasCost,
            actualGas
        );
    }

    /**
     * Emit the UserOperationPrefundTooLow event for the given UserOperation.
     *
     * @param opInfo - The details of the current UserOperation.
     */
    function _emitPrefundTooLow(UserOpInfo memory opInfo) internal virtual {
        emit UserOperationPrefundTooLow(
            opInfo.userOpHash,
            opInfo.mUserOp.sender,
            opInfo.mUserOp.nonce
        );
    }

    /**
     * Iterate over calldata PackedUserOperation array and perform account and paymaster validation.
     * @notice UserOpInfo is a global array of all UserOps while PackedUserOperation is grouped per aggregator.
     *
     * @param ops - an array of UserOps to be validated
     * @param opInfos - an array of UserOp metadata being read and filled in during this function's execution
     * @param expectedAggregator - an address of the aggregator specified for a given UserOp if any, or address(0)
     * @param opIndexOffset - an offset for the index between 'ops' and 'opInfos' arrays, see the notice.
     * @return opsLen - processed UserOps (length of "ops" array)
     */
    function _iterateValidationPhase(
        PackedUserOperation[] calldata ops,
        UserOpInfo[] memory opInfos,
        address expectedAggregator,
        uint256 opIndexOffset
    ) internal returns (uint256 opsLen){
        unchecked {
            opsLen = ops.length;
            for (uint256 i = 0; i < opsLen; i++) {
                UserOpInfo memory opInfo = opInfos[opIndexOffset + i];
                (
                    uint256 validationData,
                    uint256 pmValidationData
                ) = _validatePrepayment(opIndexOffset + i, ops[i], opInfo);
                _validateAccountAndPaymasterValidationData(
                    opIndexOffset + i,
                    validationData,
                    pmValidationData,
                    expectedAggregator
                );
            }
        }
    }

    /**
     * A memory copy of UserOp static fields only.
     * Excluding: callData, initCode and signature. Replacing paymasterAndData with paymaster.
     */
    struct MemoryUserOp {
        address sender;
        uint256 nonce;
        uint256 verificationGasLimit;
        uint256 callGasLimit;
        uint256 paymasterVerificationGasLimit;
        uint256 paymasterPostOpGasLimit;
        uint256 preVerificationGas;
        address paymaster;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
    }

    struct UserOpInfo {
        MemoryUserOp mUserOp;
        bytes32 userOpHash;
        uint256 prefund;
        uint256 contextOffset;
        uint256 preOpGas;
    }

    /**
     * Inner function to handle a UserOperation.
     * Must be declared "external" to open a call context, but it can only be called by handleOps.
     * @param callData - The callData to execute.
     * @param opInfo   - The UserOpInfo struct.
     * @param context  - The context bytes.
     * @return actualGasCost - the actual cost in eth this UserOperation paid for gas
     */
    function innerHandleOp(
        bytes memory callData,
        UserOpInfo memory opInfo,
        bytes calldata context
    ) external returns (uint256 actualGasCost) {
        uint256 preGas = gasleft();
        require(msg.sender == address(this), "AA92 internal call only");
        MemoryUserOp memory mUserOp = opInfo.mUserOp;

        uint256 callGasLimit = mUserOp.callGasLimit;
        unchecked {
        // handleOps was called with gas limit too low. abort entire bundle.
            if (
                gasleft() * 63 / 64 <
                callGasLimit +
                mUserOp.paymasterPostOpGasLimit +
                INNER_GAS_OVERHEAD
            ) {
                assembly ("memory-safe") {
                    mstore(0, INNER_OUT_OF_GAS)
                    revert(0, 32)
                }
            }
        }

        IPaymaster.PostOpMode mode = IPaymaster.PostOpMode.opSucceeded;
        if (callData.length > 0) {
            bool success = Exec.call(mUserOp.sender, 0, callData, callGasLimit);
            if (!success) {
                uint256 freePtr = _getFreePtr();
                bytes memory result = Exec.getReturnData(REVERT_REASON_MAX_LEN);
                if (result.length > 0) {
                    emit UserOperationRevertReason(
                        opInfo.userOpHash,
                        mUserOp.sender,
                        mUserOp.nonce,
                        result
                    );
                }
                _restoreFreePtr(freePtr);
                mode = IPaymaster.PostOpMode.opReverted;
            }
        }

        unchecked {
            uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
            return _postExecution(mode, opInfo, context, actualGas);
        }
    }

    /**
     * Copy general fields from userOp into the memory opInfo structure.
     * @param userOp  - The user operation.
     * @param mUserOp - The memory user operation.
     */
    function _copyUserOpToMemory(
        PackedUserOperation calldata userOp,
        MemoryUserOp memory mUserOp
    ) internal virtual pure {
        mUserOp.sender = userOp.sender;
        mUserOp.nonce = userOp.nonce;
        (mUserOp.verificationGasLimit, mUserOp.callGasLimit) = UserOperationLib.unpackUints(userOp.accountGasLimits);
        mUserOp.preVerificationGas = userOp.preVerificationGas;
        (mUserOp.maxPriorityFeePerGas, mUserOp.maxFeePerGas) = UserOperationLib.unpackUints(userOp.gasFees);
        bytes calldata paymasterAndData = userOp.paymasterAndData;
        if (paymasterAndData.length > 0) {
            require(
                paymasterAndData.length >= UserOperationLib.PAYMASTER_DATA_OFFSET,
                "AA93 invalid paymasterAndData"
            );
            address paymaster;
            (paymaster, mUserOp.paymasterVerificationGasLimit, mUserOp.paymasterPostOpGasLimit) = UserOperationLib.unpackPaymasterStaticFields(paymasterAndData);
            require(paymaster != address(0), "AA98 invalid paymaster");
            mUserOp.paymaster = paymaster;
        }
    }

    /**
     * Get the required prefunded gas fee amount for an operation.
     *
     * @param mUserOp - The user operation in memory.
     * @return requiredPrefund - the required amount.
     */
    function _getRequiredPrefund(
        MemoryUserOp memory mUserOp
    ) internal virtual pure returns (uint256 requiredPrefund) {
        unchecked {
            uint256 requiredGas = mUserOp.verificationGasLimit +
                            mUserOp.callGasLimit +
                            mUserOp.paymasterVerificationGasLimit +
                            mUserOp.paymasterPostOpGasLimit +
                            mUserOp.preVerificationGas;

            requiredPrefund = requiredGas * mUserOp.maxFeePerGas;
        }
    }

    /**
     * Create sender smart contract account if init code is provided.
     * @param opIndex  - The operation index.
     * @param opInfo   - The operation info.
     * @param initCode - The init code for the smart contract account.
     */
    function _createSenderIfNeeded(
        uint256 opIndex,
        UserOpInfo memory opInfo,
        bytes calldata initCode
    ) internal virtual {
        if (initCode.length != 0) {
            address sender = opInfo.mUserOp.sender;
            if (Eip7702Support._isEip7702InitCode(initCode)) {
                if (initCode.length > 20) {
                    // Already validated it is an EIP-7702 delegate (and hence, already has code) - see getUserOpHash()
                    // Note: Can be called multiple times as long as an appropriate initCode is supplied
                    senderCreator().initEip7702Sender{
                            gas: opInfo.mUserOp.verificationGasLimit
                        }(sender, initCode[20 :]);
                }
                return;
            }
            if (sender.code.length != 0)
                revert FailedOp(opIndex, "AA10 sender already constructed");
            if (initCode.length < 20) {
                revert FailedOp(opIndex, "AA99 initCode too small");
            }
            address sender1 = senderCreator().createSender{
                    gas: opInfo.mUserOp.verificationGasLimit
                }(initCode);
            if (sender1 == address(0))
                revert FailedOp(opIndex, "AA13 initCode failed or OOG");
            if (sender1 != sender)
                revert FailedOp(opIndex, "AA14 initCode must return sender");
            if (sender1.code.length == 0)
                revert FailedOp(opIndex, "AA15 initCode must create sender");
            address factory = address(bytes20(initCode[0 : 20]));
            emit AccountDeployed(
                opInfo.userOpHash,
                sender,
                factory,
                opInfo.mUserOp.paymaster
            );
        }
    }

    /**
     * Call account.validateUserOp.
     * Revert (with FailedOp) in case validateUserOp reverts, or account didn't send required prefund.
     * Decrement account's deposit if needed.
     * @param opIndex         - The operation index.
     * @param op              - The user operation.
     * @param opInfo          - The operation info.
     * @param requiredPrefund - The required prefund amount.
     * @return validationData - The account's validationData.
     */
    function _validateAccountPrepayment(
        uint256 opIndex,
        PackedUserOperation calldata op,
        UserOpInfo memory opInfo,
        uint256 requiredPrefund
    )
    internal virtual
    returns (
        uint256 validationData
    )
    {
        unchecked {
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            address sender = mUserOp.sender;
            _createSenderIfNeeded(opIndex, opInfo, op.initCode);
            address paymaster = mUserOp.paymaster;
            uint256 missingAccountFunds = 0;
            if (paymaster == address(0)) {
                uint256 bal = balanceOf(sender);
                missingAccountFunds = bal > requiredPrefund
                    ? 0
                    : requiredPrefund - bal;
            }
            validationData = _callValidateUserOp(opIndex, op, opInfo, missingAccountFunds);
            if (paymaster == address(0)) {
                if (!_tryDecrementDeposit(sender, requiredPrefund)) {
                    revert FailedOp(opIndex, "AA21 didn't pay prefund");
                }
            }
        }
    }

    /**
     * Make a call to the sender.validateUserOp() function.
     * Handle wrong output size by reverting with a FailedOp error.
     *
     * @param opIndex - index of the UserOperation in the bundle.
     * @param op - the packed UserOperation object.
     * @param opInfo - the in-memory UserOperation information.
     * @param missingAccountFunds - the amount of deposit the account has to make to cover the UserOperation gas.
     */
    function _callValidateUserOp(
        uint256 opIndex,
        PackedUserOperation calldata op,
        UserOpInfo memory opInfo,
        uint256 missingAccountFunds
    )
    internal virtual returns (uint256 validationData) {
        uint256 gasLimit = opInfo.mUserOp.verificationGasLimit;
        address sender = opInfo.mUserOp.sender;
        bool success;
        {
            uint256 saveFreePtr = _getFreePtr();
            bytes memory callData = abi.encodeCall(IAccount.validateUserOp, (op, opInfo.userOpHash, missingAccountFunds));
            assembly ("memory-safe"){
                success := call(gasLimit, sender, 0, add(callData, 0x20), mload(callData), 0, 32)
                validationData := mload(0)
            // any return data size other than 32 is considered failure
                if iszero(eq(returndatasize(), 32)) {
                    success := 0
                }
            }
            _restoreFreePtr(saveFreePtr);
        }
        if (!success) {
            if (sender.code.length == 0) {
                revert FailedOp(opIndex, "AA20 account not deployed");
            } else {
                revert FailedOpWithRevert(opIndex, "AA23 reverted", Exec.getReturnData(REVERT_REASON_MAX_LEN));
            }
        }
    }

    /**
     * In case the request has a paymaster:
     *  - Validate paymaster has enough deposit.
     *  - Call paymaster.validatePaymasterUserOp.
     *  - Revert with proper FailedOp in case paymaster reverts.
     *  - Decrement paymaster's deposit.
     * @param opIndex                            - The operation index.
     * @param op                                 - The user operation.
     * @param opInfo                             - The operation info.
     * @return context                           - The Paymaster-provided value to be passed to the 'postOp' function later
     * @return validationData                    - The Paymaster's validationData.
     */
    function _validatePaymasterPrepayment(
        uint256 opIndex,
        PackedUserOperation calldata op,
        UserOpInfo memory opInfo
    ) internal virtual returns (bytes memory context, uint256 validationData) {
        unchecked {
            uint256 preGas = gasleft();
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            address paymaster = mUserOp.paymaster;
            uint256 requiredPreFund = opInfo.prefund;
            if (!_tryDecrementDeposit(paymaster, requiredPreFund)) {
                revert FailedOp(opIndex, "AA31 paymaster deposit too low");
            }
            uint256 pmVerificationGasLimit = mUserOp.paymasterVerificationGasLimit;
            (context, validationData) = _callValidatePaymasterUserOp(opIndex, op, opInfo);
            if (preGas - gasleft() > pmVerificationGasLimit) {
                revert FailedOp(opIndex, "AA36 over paymasterVerificationGasLimit");
            }
        }
    }

    function _callValidatePaymasterUserOp(
        uint256 opIndex,
        PackedUserOperation calldata op,
        UserOpInfo memory opInfo
    ) internal returns (bytes memory context, uint256 validationData)  {
        uint256 freePtr = _getFreePtr();
        bytes memory validatePaymasterCall = abi.encodeCall(
            IPaymaster.validatePaymasterUserOp,
            (op, opInfo.userOpHash, opInfo.prefund)
        );
        address paymaster = opInfo.mUserOp.paymaster;
        uint256 paymasterVerificationGasLimit = opInfo.mUserOp.paymasterVerificationGasLimit;
        bool success;
        uint256 contextLength;
        uint256 contextOffset;
        uint256 maxContextLength;
        uint256 len;
        assembly ("memory-safe") {
            success := call(paymasterVerificationGasLimit, paymaster, 0, add(validatePaymasterCall, 0x20), mload(validatePaymasterCall), 0, 0)
            len := returndatasize()
            // return data from validatePaymasterUserOp is (bytes context, validationData)
            // encoded as:
            // 32 bytes offset of context (always 64)
            // 32 bytes of validationData
            // 32 bytes of context length
            // context data (rounded up, to 32 bytes boundary)
            // so entire buffer size is (at least) 96+content.length.
            //
            // we use freePtr, fetched before calling encodeCall, as return data pointer.
            // this way we reuse that memory without unnecessary memory expansion
            returndatacopy(freePtr, 0, len)
            validationData := mload(add(freePtr, 32))
            contextOffset := mload(freePtr)
            maxContextLength := sub(len, 96)
            context := add(freePtr, 64)
            contextLength := mload(context)
        }

        unchecked {
            if (!success || contextOffset != 64 || contextLength + 31 < maxContextLength) {
                revert FailedOpWithRevert(opIndex, "AA33 reverted", Exec.getReturnData(REVERT_REASON_MAX_LEN));
            }
        }
        finalizeAllocation(freePtr, len);
    }

    /**
     * Revert if either account validationData or paymaster validationData is expired.
     * @param opIndex                 - The operation index.
     * @param validationData          - The account validationData.
     * @param paymasterValidationData - The paymaster validationData.
     * @param expectedAggregator      - The expected aggregator.
     */
    function _validateAccountAndPaymasterValidationData(
        uint256 opIndex,
        uint256 validationData,
        uint256 paymasterValidationData,
        address expectedAggregator
    ) internal virtual view {
        (address aggregator, bool outOfTimeRange) = _getValidationData(
            validationData
        );
        if (expectedAggregator != aggregator) {
            revert FailedOp(opIndex, "AA24 signature error");
        }
        if (outOfTimeRange) {
            revert FailedOp(opIndex, "AA22 expired or not due");
        }
        // pmAggregator is not a real signature aggregator: we don't have logic to handle it as address.
        // Non-zero address means that the paymaster fails due to some signature check (which is ok only during estimation).
        address pmAggregator;
        (pmAggregator, outOfTimeRange) = _getValidationData(
            paymasterValidationData
        );
        if (pmAggregator != address(0)) {
            revert FailedOp(opIndex, "AA34 signature error");
        }
        if (outOfTimeRange) {
            revert FailedOp(opIndex, "AA32 paymaster expired or not due");
        }
    }

    /**
     * Parse validationData into its components.
     * @param validationData - The packed validation data (sigFailed, validAfter, validUntil).
     * @return aggregator the aggregator of the validationData
     * @return outOfTimeRange true if current time is outside the time range of this validationData.
     */
    function _getValidationData(
        uint256 validationData
    ) internal virtual view returns (address aggregator, bool outOfTimeRange) {
        if (validationData == 0) {
            return (address(0), false);
        }
        ValidationData memory data = _parseValidationData(validationData);
        // solhint-disable-next-line not-rely-on-time
        outOfTimeRange = block.timestamp > data.validUntil || block.timestamp <= data.validAfter;
        aggregator = data.aggregator;
    }

    /**
     * Validate account and paymaster (if defined) and
     * also make sure total validation doesn't exceed verificationGasLimit.
     * This method is called off-chain (simulateValidation()) and on-chain (from handleOps)
     * @param opIndex    - The index of this userOp into the "opInfos" array.
     * @param userOp     - The packed calldata UserOperation structure to validate.
     * @param outOpInfo  - The empty unpacked in-memory UserOperation structure that will be filled in here.
     *
     * @return validationData          - The account's validationData.
     * @return paymasterValidationData - The paymaster's validationData.
     */
    function _validatePrepayment(
        uint256 opIndex,
        PackedUserOperation calldata userOp,
        UserOpInfo memory outOpInfo
    )
    internal virtual
    returns (uint256 validationData, uint256 paymasterValidationData)
    {
        uint256 preGas = gasleft();
        MemoryUserOp memory mUserOp = outOpInfo.mUserOp;
        _copyUserOpToMemory(userOp, mUserOp);

        // getUserOpHash uses temporary allocations, no required after it returns
        uint256 freePtr = _getFreePtr();
        outOpInfo.userOpHash = getUserOpHash(userOp);
        _restoreFreePtr(freePtr);

        // Validate all numeric values in userOp are well below 128 bit, so they can safely be added
        // and multiplied without causing overflow.
        uint256 verificationGasLimit = mUserOp.verificationGasLimit;
        uint256 maxGasValues = mUserOp.preVerificationGas |
                    verificationGasLimit |
                        mUserOp.callGasLimit |
                        mUserOp.paymasterVerificationGasLimit |
                        mUserOp.paymasterPostOpGasLimit |
                        mUserOp.maxFeePerGas |
                        mUserOp.maxPriorityFeePerGas;
        require(maxGasValues <= type(uint120).max, FailedOp(opIndex, "AA94 gas values overflow"));

        uint256 requiredPreFund = _getRequiredPrefund(mUserOp);
        outOpInfo.prefund = requiredPreFund;
        validationData = _validateAccountPrepayment(
            opIndex,
            userOp,
            outOpInfo,
            requiredPreFund
        );

        require(
            _validateAndUpdateNonce(mUserOp.sender, mUserOp.nonce),
            FailedOp(opIndex, "AA25 invalid account nonce")
        );

        unchecked {
            if (preGas - gasleft() > verificationGasLimit) {
                revert FailedOp(opIndex, "AA26 over verificationGasLimit");
            }
        }

        bytes memory context;
        if (mUserOp.paymaster != address(0)) {
            (context, paymasterValidationData) = _validatePaymasterPrepayment(
                opIndex,
                userOp,
                outOpInfo
            );
        }
        unchecked {
            outOpInfo.contextOffset = _getOffsetOfMemoryBytes(context);
            outOpInfo.preOpGas = preGas - gasleft() + userOp.preVerificationGas;
        }
    }

    /**
     * Process post-operation, called just after the callData is executed.
     * If a paymaster is defined and its validation returned a non-empty context, its postOp is called.
     * The excess amount is refunded to the account (or paymaster - if it was used in the request).
     * @param mode      - Whether is called from innerHandleOp, or outside (postOpReverted).
     * @param opInfo    - UserOp fields and info collected during validation.
     * @param context   - The context returned in validatePaymasterUserOp.
     * @param actualGas - The gas used so far by this user operation.
     *
     * @return actualGasCost - the actual cost in eth this UserOperation paid for gas
     */
    function _postExecution(
        IPaymaster.PostOpMode mode,
        UserOpInfo memory opInfo,
        bytes memory context,
        uint256 actualGas
    ) internal virtual returns (uint256 actualGasCost) {
        uint256 preGas = gasleft();
        unchecked {
            address refundAddress;
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            uint256 gasPrice = _getUserOpGasPrice(mUserOp);

            address paymaster = mUserOp.paymaster;
        // Calculating a penalty for unused execution gas
            {
                uint256 executionGasUsed = actualGas - opInfo.preOpGas;
                // this check is required for the gas used within EntryPoint and not covered by explicit gas limits
                actualGas += _getUnusedGasPenalty(executionGasUsed, mUserOp.callGasLimit);
            }
            uint256 postOpUnusedGasPenalty;
            if (paymaster == address(0)) {
                refundAddress = mUserOp.sender;
            } else {
                refundAddress = paymaster;
                if (context.length > 0) {
                    actualGasCost = actualGas * gasPrice;
                    uint256 postOpPreGas = gasleft();
                    if (mode != IPaymaster.PostOpMode.postOpReverted) {
                        try IPaymaster(paymaster).postOp{
                                gas: mUserOp.paymasterPostOpGasLimit
                            }(mode, context, actualGasCost, gasPrice)
                        // solhint-disable-next-line no-empty-blocks
                        {} catch {
                            bytes memory reason = Exec.getReturnData(REVERT_REASON_MAX_LEN);
                            revert PostOpReverted(reason);
                        }
                    }
                    // Calculating a penalty for unused postOp gas
                    // note that if postOp is reverted, the maximum penalty (10% of postOpGasLimit) is charged.
                    uint256 postOpGasUsed = postOpPreGas - gasleft();
                    postOpUnusedGasPenalty = _getUnusedGasPenalty(postOpGasUsed, mUserOp.paymasterPostOpGasLimit);
                }
            }
            actualGas += preGas - gasleft() + postOpUnusedGasPenalty;
            actualGasCost = actualGas * gasPrice;
            uint256 prefund = opInfo.prefund;
            if (prefund < actualGasCost) {
                if (mode == IPaymaster.PostOpMode.postOpReverted) {
                    actualGasCost = prefund;
                    _emitPrefundTooLow(opInfo);
                    _emitUserOperationEvent(opInfo, false, actualGasCost, actualGas);
                } else {
                    assembly ("memory-safe") {
                        mstore(0, INNER_REVERT_LOW_PREFUND)
                        revert(0, 32)
                    }
                }
            } else {
                uint256 refund = prefund - actualGasCost;
                _incrementDeposit(refundAddress, refund);
                bool success = mode == IPaymaster.PostOpMode.opSucceeded;
                _emitUserOperationEvent(opInfo, success, actualGasCost, actualGas);
            }
        } // unchecked
    }

    /**
     * The gas price this UserOp agrees to pay.
     * Relayer/block builder might submit the TX with higher priorityFee, but the user should not be affected.
     * @param mUserOp - The userOp to get the gas price from.
     */
    function _getUserOpGasPrice(
        MemoryUserOp memory mUserOp
    ) internal view returns (uint256) {
        unchecked {
            uint256 maxFeePerGas = mUserOp.maxFeePerGas;
            uint256 maxPriorityFeePerGas = mUserOp.maxPriorityFeePerGas;
            return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
        }
    }

    /**
     * The offset of the given bytes in memory.
     * @param data - The bytes to get the offset of.
     */
    function _getOffsetOfMemoryBytes(
        bytes memory data
    ) internal pure returns (uint256 offset) {
        assembly ("memory-safe") {
            offset := data
        }
    }

    /**
     * The bytes in memory at the given offset.
     * @param offset - The offset to get the bytes from.
     */
    function _getMemoryBytesFromOffset(
        uint256 offset
    ) internal pure returns (bytes memory data) {
        assembly ("memory-safe") {
            data := offset
        }
    }

    /**
     * save free memory pointer.
     * save "free memory" pointer, so that it can be restored later using restoreFreePtr.
     * This reduce unneeded memory expansion, and reduce memory expansion cost.
     * NOTE: all dynamic allocations between saveFreePtr and restoreFreePtr MUST NOT be used after restoreFreePtr is called.
     */
    function _getFreePtr() internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
        }
    }

    /**
     * restore free memory pointer.
     * any allocated memory since saveFreePtr is cleared, and MUST NOT be accessed later.
     */
    function _restoreFreePtr(uint256 ptr) internal pure {
        assembly ("memory-safe") {
            mstore(0x40, ptr)
        }
    }

    function _getUnusedGasPenalty(uint256 gasUsed, uint256 gasLimit) internal pure returns (uint256) {
        unchecked {
            if (gasLimit <= gasUsed + PENALTY_GAS_THRESHOLD) {
                return 0;
            }
            uint256 unusedGas = gasLimit - gasUsed;
            uint256 unusedGasPenalty = (unusedGas * UNUSED_GAS_PENALTY_PERCENT) / 100;
            return unusedGasPenalty;
        }
    }
}