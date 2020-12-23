pragma solidity 0.6.12;

interface IValidatorSetAuRa {
    function miningByStakingAddress(address) external view returns (address);

    function areDelegatorsBanned(address) external view returns (bool);

    function isValidatorOrPending(address) external view returns (bool);
}
