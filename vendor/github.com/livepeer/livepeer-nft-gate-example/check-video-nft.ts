import "isomorphic-fetch";
import { ethers, BigNumber } from "ethers";
import * as standards from "./standards";
import fs from "fs";

const frontend = fs.readFileSync(__dirname + "/dist/index.html", "utf8");

const ERC721 = "erc721";
const ERC1155 = "erc1155";
const SIGN_STRING = "I have a Lens profile. Give me access.";

const chainList = require("./chains");
type Chains = {
  [key: string]: any;
};
const chains: Chains = {};
for (const chain of chainList) {
  const hex = `0x${chain.chainId.toString(16)}`;
  for (let key of [chain.shortName, chain.chainId, hex]) {
    key = `${key}`.toLowerCase();
    if (chains[key]) {
      console.error(
        `duplicate for key ${key}: ${chains[key].name} and ${chain.name}`
      );
    } else {
      chains[key] = chain;
    }
  }
}

function validateUserName(username){
  var usernameRegex = /^[a-zA-Z0-9-]+$/;
  return usernameRegex.test(username);
}

type GateParams = {
  contract?: string;
  standard?: string;
  network?: string;
  message?: string;
  proof?: string;
};
async function getResponse({
  contract,
  standard = ERC721,
  network = "eth",
  message = SIGN_STRING,
  proof,
}: GateParams): Promise<BigNumber> {
  if (!contract) {
    throw new Error("missing contract");
  }
  if (!proof) {
    throw new Error("Missing proof");
  }
  //const chain = chains[network.toLowerCase()];
  const chain = chains["matic"];
  if (! validateUserName(message)) {
    throw new Error(`username has invalid characters ${message}`);
  }
  if (message.length > 30) {
    throw new Error(`username is too long`);
  }
  if (!chain) {
    throw new Error(`network ${network} not found`);
  }
  let rpc;
  for (const url of chain.rpc) {
    if (!url.startsWith("https://")) {
      continue;
    }

    // Skip URLs that require interpolation (API Keys)
    if (url.includes("${")) {
      continue;
    }

    rpc = url;
    break;
  }
  if (!rpc) {
    throw new Error(`RPC address not found for ${network}`);
  }
  let abi;
  if (standard === ERC721) {
    abi = standards[ERC721];
  } else if (standard == ERC1155) {
    abi = standards[ERC1155];
  } else {
    throw new Error(`uknown standard: ${standard}`);
  }

  // const provider = ethers.getDefaultProvider(ETH_URL);
  const provider = new ethers.providers.StaticJsonRpcProvider(
    {
      url: rpc,
      skipFetchSetup: true,
      headers: {
        "user-agent": "livepeer/gate",
      },
    },
    chain.chainId
  );

  const lensContract = "0xdb46d1dc155634fbc732f92e853b10b288ad5a1d";

  const contractObj = new ethers.Contract("0xdb46d1dc155634fbc732f92e853b10b288ad5a1d", abi, provider);

  const address = ethers.utils.verifyMessage(message, proof);
  const balance = await contractObj.balanceOf(address);

  if (balance > 0) {
    console.log(`balance is ${balance}`);
    console.log(`fetch http://localhost:8001/user?${network}:${message}:${address}`);
    const res = await fetch(`http://localhost:8001/user?${network}:${message}:${address}`.toLowerCase(), {
      method: "GET",
    });
    if (res.status !== 200) {
        console.log(`server status: ${res.status}`);
        return res.status;
    }
  }
  return balance;
}

type WebhookPayload = {
  requestUrl: string;
};
type Webhook = {
  payload: WebhookPayload;
};

async function handleRequest(request: Request): Promise<Response> {
  if (request.method === "GET") {
    console.log("Method: GET");
    // Print out the frontend if present
    return new Response(frontend, {
      headers: { "content-type": "text/html; charset=UTF-8" },
    });
  }

  const gateParams: GateParams = {};
  // Extract parameters from query params
  const { searchParams } = new URL(request.url);
  for (const [key, value] of searchParams) {
    console.log("get Param: " + key);
    console.log("Value: " + value);
    gateParams[key] = value;
  }

  // Extract proof from webhook body
  console.log("Extract proof from webhook body")
  const data = (await request.json()) as Webhook;
  console.dir(data);
  const requestUrl: string = data?.payload?.requestUrl;
  if (!requestUrl) {
    console.log("payload.url not found");
    return new Response("payload.url not found", { status: 413 });
  }
  const payloadUrl = new URL(requestUrl);
  console.log("getting proof");
  const proof = payloadUrl.searchParams.get("proof");
  console.log("got proof " + proof);
  if (!proof) {
    return new Response("`proof` query parameter missing from payload url");
  }
  gateParams.proof = proof;
  var Balance;
  try {
    console.log("get balance");
    const balance = await getResponse(gateParams);
    console.log("balance type " + typeof balance);
    Balance = balance; 
    if (balance.gt(0)) {
      console.log("balance is greater than 0");
      return new Response("Success", { status: 302 });
      //return new Response("ok", { status: 200 });
    } else {
      return new Response(`You do not have a Lens profile, please visit https://lens.xyz`, {
        status: 403,
      });
    }
  } catch (e: any) {
    console.log("got an error");
    console.dir(e);
    console.log("bal type " + typeof Balance);

    if (typeof Balance === "number" && Balance == 409)
      errMsg = `The username '${gateParams["network"]}' is already taken, please choose another.`;
    else
      errMsg = e.message;
    console.log(`error message ${errMsg}`);
    return new Response(errMsg, typeof Balance === "number" ? { status: Balance } : { status: 500 });
  }
}

if (typeof addEventListener === "function") {
  addEventListener("fetch", (event) => {
    event.respondWith(handleRequest(event.request as Request));
  });
} else if (typeof module === "object" && !module.parent) {
  getResponse({
    standard: "erc721",
    contract: "0x69c53e7b8c41bf436ef5a2d81db759dc8bd83b5f",
    network: "matic",
    proof:
      "0xcf3708006566be50200fb4257f97e36f1fe3ad2c34a2c03d6395aa71b81ed8186af1432d1aa4e43284dfb2bf1e3b0f0b063ad461172f116685b8e842953cb2b71b",
  })
    .then((x) => console.log(x.toNumber()))
    .catch((...x) => console.log(x));
}
