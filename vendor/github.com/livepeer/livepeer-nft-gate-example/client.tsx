import React, { useState, useEffect, useRef } from "react";
import ReactDOM from "react-dom";
import { ethers } from "ethers";
import HLS from "hls.js";

declare let window: any;

// Hydrate the starting parameters
const initialGate = {
  contract: "",
  network: "eth",
  standard: "erc721",
  message: `Hello, I hold this NFT. Please let me in.`,
};

const firstUrl = new URL(window.location.href);
for (const [key, value] of firstUrl.searchParams) {
  for (const gateKey of Object.keys(initialGate)) {
    if (key === gateKey) {
      initialGate[key] = value;
    }
  }
}

const sample = (gateParams) => `
{
  "name": "gate for ${gateParams.contract}",
  "url": "${window.location.href}",
  "events": ["playback.user.new"]
}
`;

const App = () => {
  const [errorText, setErrorText] = useState("");
  const [showVideo, setShowVideo] = useState(false);
  const [proof, setProof] = useState(null);
  const [gate, setGate] = useState(initialGate);

  useEffect(() => {
    const params = new URLSearchParams(gate);
    const newUrl = new URL(window.location.href);
    newUrl.search = `?${params}`;
    window.history.replaceState(null, "", newUrl);
  }, [gate]);

  return (
    <main>
      <br/>
      <br/>
      <br/>
      <h3>We will verify your account has a Lens profile using the below information:</h3>


      <button class="button" style={{ color: "black" }}
        onClick={async () => {
          try {
	    console.log("Get provider");
            setErrorText("Please wait for verification to complete");
		(function () {

		    var i = 0;
		    window.loop = true;
		    var callback = function() { 
			i++
			var msg="Please wait for verification to complete"
			for(var j=0; j < i; j++)
			  msg=msg+"."
            		if (window.loop)
			  setErrorText(msg)
		    };

		    callback();

		    window.setInterval(callback, 500);
		})();
            const provider = new ethers.providers.Web3Provider(
              window.ethereum,
              "any"
            );
            // Prompt user for account connections
	    console.log("requests accounts");
            await provider.send("eth_requestAccounts", []);
	    console.log("provider.getSigner");
            const signer = provider.getSigner();
	    console.log("signer.signMessage");
            const signed = await signer.signMessage(gate.message);
	    console.log("Fetch the asset " + `https://example.com/hls/fake-stream.m3u8?streamId=fake-stream&proof=${encodeURIComponent(signed)}`);
            const res = await fetch(window.location.href, {
              method: "POST",
              body: JSON.stringify({
                payload: {
                  requestUrl: `https://example.com/hls/fake-stream.m3u8?streamId=fake-stream&proof=${encodeURIComponent(
                    signed
                  )}`,
                },
              }),
            });
            const data = await res.text();

            if (res.status !== 200) {
	      window.loop = false;
              setErrorText(data);
	      const ua = navigator.userAgent;
	      var device = "Other";
		const isMobile = {
		  android() {
		    return /Android/i.test(navigator.userAgent);
		  },
		  iOS() {
		    return /iPhone|iPad|iPod/i.test(navigator.userAgent);
		  },
		};
	      if (data == "Success" && isMobile.android())
                setErrorText(`Good news, your profile has been verified! Please close this MetaMask tab, then click on the b3.live floating window and hit the 'resize button' ⤢ to return to the app.`);
	      else if (data == "Success")
                setErrorText(`Good news, your profile has been verified! Please close this MetaMask tab, then navigate back to the b3.live app`);
              return;
            }
            console.log(data);
            setProof(signed);
          } catch (e) {
            setErrorText(e.message);
          }
        }}
      >
       Verify
      </button>
      <div>
        Address:
        <input
          value={gate.contract}
          onChange={(e) => setGate({ ...gate, contract: "0xd2e970718Aa32f2db4Bf94AafC22fDF866C3ff01" /*e.target.value*/ })}
        ></input>
      </div>
      <div>
        Token Standard (default erc721)
        <div style={{ display: "none" }}
          onChange={(e) =>
            setGate({ ...gate, standard: (e.target as any).value })
          }
        >
          &nbsp;ERC-721
          <input
            type="radio"
            value="erc721"
            name="standard"
            checked={gate.standard === "erc721"}
          />
          &nbsp;ERC-1155
          <input
            type="radio"
            value="erc1155"
            name="standard"
            checked={gate.standard === "erc1155"}
          />
        </div>
      </div>
      <div style={{ display: "none" }}>
        User Name:
        <input
          value={gate.network}
          onChange={(e) => setGate({ ...gate, network: e.target.value })}
          placeholder="eth"
        ></input>
      </div>
      <div style={{ display: "none" }}>
        Message:
        <input
          value={gate.message}
          onChange={(e) => setGate({ ...gate, message: e.target.value })}
          placeholder="I have the NFT! Give me access."
        ></input>
      </div>

      <h3 style={{ color: "red" }}>{errorText}</h3>
      {proof && <MistPlayer index={proof} proof={proof} />}

    </main>
  );
};

const MistPlayer = ({ proof, index }) => {
  useEffect(() => {
    setTimeout(() => {
      var a = function () {
        window.mistPlay("5208b31slogl2gw4", {
          target: document.getElementById("mistvideo"),
          urlappend: `?proof=${proof}`,
          // forcePlayer: "hlsjs",
          // forceType: "html5/application/vnd.apple.mpegurl",
          // forcePriority: {
          //   source: [["type", ["html5/application/vnd.apple.mpegurl"]]],
          // },
        });
      };
      if (!window.mistplayers) {
        var p = document.createElement("script");
        p.src = "https://playback.livepeer.engineering/player.js";
        document.head.appendChild(p);
        p.onload = a;
      } else {
        a();
      }
    });
  }, [proof]);
  return <div className="mistvideo" id="mistvideo"></div>;
};

ReactDOM.render(<App />, document.querySelector("main"));
