// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Functions, FunctionsClient} from "../dev/functions/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error AgreementAlreadySigned();
error ProjectDoesNotExist();
error ProjectRequiresKeywords();
error SignerIsNotKOL();

contract CommunityEngine is FunctionsClient, ConfirmedOwner {
  using Functions for Functions.Request;
  using SafeERC20 for IERC20;

  struct Project {
    address owner;
    string name;
    address kol;
    address tokenAddress;
    uint256 numTokensToPayout;
    bool isComplete;
    bool kolHasAgreed;
    bool exists;
    string twitterHandle;
    string[] tweetKeywords;
  }

  struct KOLProjectMapping {
    address owner;
    string projectName;
  }

  bytes32 public latestRequestId;
  bytes public latestResponse;
  bytes public latestError;

  /// @notice A KOL's list of project names with their respective project owner.
  mapping(address => KOLProjectMapping[]) public kolProjectMappings;

  //// @notice A project owner's projects.
  mapping(address => mapping(string => Project)) public projects;
  mapping(bytes32 => KOLProjectMapping) public requestIdToProjectMapping;

  /// @notice A project owner's list of project names.
  mapping(address => string[]) public projectOwnerProjectNames;

  event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

  constructor(address oracle) FunctionsClient(oracle) ConfirmedOwner(msg.sender) {}

  /// @notice Add a new project for a KOL to be a part of.
  function addProject(
    string memory projectName,
    address kol,
    address tokenAddress,
    uint256 numTokensToPayout,
    string memory twitterHandle
  ) external {
    require(numTokensToPayout > 0, "payment must be greater than 0");

    // deposit tokens into contract
    IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), numTokensToPayout);

    projects[msg.sender][projectName] = Project({
      owner: msg.sender,
      name: projectName,
      kol: kol,
      tokenAddress: tokenAddress,
      numTokensToPayout: numTokensToPayout,
      isComplete: false,
      kolHasAgreed: false,
      exists: true,
      twitterHandle: twitterHandle,
      tweetKeywords: new string[](0)
    });

    kolProjectMappings[kol].push(KOLProjectMapping({owner: msg.sender, projectName: projectName}));
    projectOwnerProjectNames[msg.sender].push(projectName);
  }

  /// @notice Allows for a KOL of a project to activate project.
  function signAgreement(string memory projectName, string[] memory tweetKeywords) external {
    if (tweetKeywords.length == 0) {
      revert ProjectRequiresKeywords();
    }

    Project storage project = projects[msg.sender][projectName];
    if (!project.exists) {
      revert ProjectDoesNotExist();
    }
    if (msg.sender != project.kol) {
      revert SignerIsNotKOL();
    }
    if (project.kolHasAgreed) {
      revert AgreementAlreadySigned();
    }

    project.kolHasAgreed = true;

    for (uint256 i = 0; i < tweetKeywords.length; i++) {
      project.tweetKeywords.push(tweetKeywords[i]);
    }
  }

  /// @notice Returns an array of Projects a KOL is associated with.
  function getKOLProjects(address account) external view returns (Project[] memory) {
    KOLProjectMapping[] memory projectMappings = kolProjectMappings[account];
    Project[] memory kolProjects = new Project[](projectMappings.length);

    for (uint256 i = 0; i < projectMappings.length; i++) {
      Project memory project = projects[projectMappings[i].owner][projectMappings[i].projectName];
      kolProjects[i] = project;
    }

    return kolProjects;
  }

  /// @notice Returns an array of Projects a project owner has setup.
  function getProjectOwnerProjects(address account) external view returns (Project[] memory) {
    string[] memory ownerProjectNames = projectOwnerProjectNames[msg.sender];
    Project[] memory ownerProjects = new Project[](ownerProjectNames.length);

    for (uint256 i = 0; i < ownerProjectNames.length; i++) {
      Project memory project = projects[account][ownerProjectNames[i]];
      ownerProjects[i] = project;
    }

    return ownerProjects;
  }

  /**
   * @notice Send a simple request
   *
   * @param source JavaScript source code
   * @param secrets Encrypted secrets payload
   * @param args List of arguments accessible from within the source code
   * @param subscriptionId Billing ID
   * @param gasLimit Maximum amount of gas used to call the client contract's `handleOracleFulfillment` function
   * @return Functions request ID
   */
  function executeRequest(
    string calldata source,
    bytes calldata secrets,
    string[] calldata args, // args in sequence are: owner, projectName, twitterHandle
    uint64 subscriptionId,
    uint32 gasLimit
  ) public onlyOwner returns (bytes32) {
    Functions.Request memory req;
    req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);

    if (secrets.length > 0) {
      req.addRemoteSecrets(secrets);
    }
    if (args.length > 0) {
      req.addArgs(args);
    }

    // Update storage variables.
    bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
    latestRequestId = assignedReqID;

    requestIdToProjectMapping[assignedReqID] = KOLProjectMapping({owner: parseAddr(args[0]), projectName: args[1]});

    return assignedReqID;
  }

  /**
   * @notice Callback that is invoked once the DON has resolved the request or hit an error
   *
   * @param requestId The request ID, returned by sendRequest()
   * @param response Aggregated response from the user code
   * @param err Aggregated error from the user code or from the execution pipeline
   * Either response or error parameter will be set, but never both
   */
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    latestResponse = response;
    latestError = err;
    emit OCRResponse(requestId, response, err);

    bool nilErr = (err.length == 0);
    if (nilErr) {
      KOLProjectMapping memory projectMapping = requestIdToProjectMapping[requestId];
      Project storage project = projects[projectMapping.owner][projectMapping.projectName];

      bool keywordsFound = (uint256(bytes32(response)) % 2) == 1;

      // project was success, pay the kol the agreed upon tokens
      if (keywordsFound) {
        transferTokens(project.kol, project.tokenAddress, project.numTokensToPayout);
        project.isComplete = true;
      } else {
        // kol broke the rules :( send tokens back to the project owner
        transferTokens(project.owner, project.tokenAddress, project.numTokensToPayout);
        project.isComplete = true;
      }
    }
  }

  function updateOracleAddress(address oracle) public onlyOwner {
    setOracle(oracle);
  }

  function addSimulatedRequestId(address oracleAddress, bytes32 requestId) public onlyOwner {
    addExternalRequest(oracleAddress, requestId);
  }

  function transferTokens(address account, address tokenAddress, uint256 numTokensToPayout) private {
    IERC20(tokenAddress).safeTransfer(account, numTokensToPayout);
  }

  function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
    bytes memory tmp = bytes(_a);
    uint160 iaddr = 0;
    uint160 b1;
    uint160 b2;
    for (uint i = 2; i < 2 + 2 * 20; i += 2) {
      iaddr *= 256;
      b1 = uint160(uint8(tmp[i]));
      b2 = uint160(uint8(tmp[i + 1]));
      if ((b1 >= 97) && (b1 <= 102)) {
        b1 -= 87;
      } else if ((b1 >= 65) && (b1 <= 70)) {
        b1 -= 55;
      } else if ((b1 >= 48) && (b1 <= 57)) {
        b1 -= 48;
      }
      if ((b2 >= 97) && (b2 <= 102)) {
        b2 -= 87;
      } else if ((b2 >= 65) && (b2 <= 70)) {
        b2 -= 55;
      } else if ((b2 >= 48) && (b2 <= 57)) {
        b2 -= 48;
      }
      iaddr += (b1 * 16 + b2);
    }
    return address(iaddr);
  }
}
