# Traffic Engineering with BGP

In the previous chapter, we learned how to safely accept routes from others. Now, we move to the next level of BGP operations: **Traffic Engineering (TE)**.

Traffic Engineering is the process of steering traffic across your network to achieve specific goals, such as:
*   Preferring a cheaper provider over an expensive one.
*   Using a high-bandwidth link for heavy traffic.
*   Ensuring a backup link remains idle unless the primary fails.

---

## 1. The Two Directions of Traffic

When performing TE, you must always think in two directions:
1.  **Outbound Traffic (Traffic Leaving Your Network):** How *your* users reach the Internet. This is easy to control because you make the decision locally.
2.  **Inbound Traffic (Traffic Entering Your Network):** How the *Internet* reaches your users. This is harder to control because you are trying to influence decisions made by routers you don't own.

> **Crucial Rule:** Traffic follows the **opposite** path of the BGP advertisements. If you want traffic to come *in* via Provider A, you must make your BGP advertisements to Provider A look more attractive than those to Provider B.

---

## 2. Influencing Outbound Traffic

To choose which "exit" your traffic takes, the primary tool is **Local Preference**.

### Local Preference (Local-Pref)
*   **Scope:** Entire Autonomous System (iBGP).
*   **Preference:** Higher is better (Default is 100).
*   **Use Case:** If you have two ISPs, and you want to prefer ISP-A for all traffic.

#### Hands-on: Preferring an ISP with Local-Pref
Imagine R1 is connected to ISP-A and R2 is connected to ISP-B. We want to prefer ISP-A.

```text
! On R1 (Connected to ISP-A)
route-map RM-PREFER-ISP-A permit 10
 set local-preference 200
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.0.1.1 route-map RM-PREFER-ISP-A in
 exit-address-family
```

### Weight (FRR/Cisco Specific)
*   **Scope:** Local router only (does not pass to iBGP peers).
*   **Preference:** Higher is better (Default 0 for learned routes, 32768 for routes the router originates).
*   **Use Case:** Quickly choosing an exit point on a single router with multiple links.

---

## 3. Influencing Inbound Traffic

This is the "Art" of BGP. You are trying to convince the rest of the world to prefer one of your links over another.

### AS-PATH Prepending
BGP prefers shorter AS_PATHs. To make a link *less* attractive, you can artificially lengthen the path by repeating your own ASN multiple times.

#### Hands-on: Making ISP-B a Backup Link
We want the world to use ISP-A to reach us. We will "prepend" our ASN (65000) three times towards ISP-B.

```text
! On the router connected to ISP-B
route-map RM-AS-PREPEND permit 10
 set as-path prepend 65000 65000 65000
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.0.2.1 route-map RM-AS-PREPEND out
 exit-address-family
```

### The "More-Specific" Trick
Traffic always follows the **Longest Match**. If you announce `192.0.2.0/24` to ISP-A and `192.0.2.0/25` + `192.0.2.128/25` to ISP-B, all traffic for that range will go to ISP-B, regardless of any other BGP attributes.

*   *Warning:* This contributes to global routing table bloat and should be used sparingly.
*   *Warning:* Most networks filter prefixes longer than /24 (see "Accepting Routes from Others"), so splitting a /24 into /25s, as in this example, only works with neighbors that accept them. In practice, the trick is used on larger blocks, for example a /23 split into two /24s.

---

## 4. BGP Communities: The "Remote Control"

A **Community** ([RFC 1997](https://datatracker.ietf.org/doc/html/rfc1997)) is a 32-bit tag, usually written as `ASN:VALUE` with two 16-bit numbers, added to a route. It doesn't change path selection by itself, but it can trigger actions on other routers. Since a 32-bit ASN doesn't fit in 16 bits, networks with 4-byte ASNs use **Large Communities** ([RFC 8092](https://datatracker.ietf.org/doc/html/rfc8092)), written `ASN:VALUE1:VALUE2`.

### Standard Communities
*   **no-export (65535:65281):** "Do not announce this route outside of my AS."
*   **no-advertise (65535:65282):** "Do not announce this route to *any* peer (iBGP or eBGP)."

#### Hands-on: Using No-Export
You want to announce a prefix to your ISP so they can reach you, but you don't want them to pass that route to their other customers or providers.

```text
route-map RM-INTERNAL-ONLY permit 10
 set community no-export
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.0.1.1 route-map RM-INTERNAL-ONLY out
 exit-address-family
```
*Note: FRR sends communities to all neighbors by default (you can turn it off with `no neighbor 10.0.1.1 send-community`). Cisco IOS is the opposite: there you must add `neighbor 10.0.1.1 send-community`, or the tags are stripped before the update is sent!*

Lab 4 uses a community to implement Remote Triggered Blackholing for a customer.

---

## 5. Summary: The TE Hierarchy

When you have multiple attributes set, BGP follows a strict hierarchy (The Best Path Selection Algorithm).

| Attribute | Direction Controlled | Scope | Preference |
| :--- | :--- | :--- | :--- |
| **Weight** | Outbound | Local Router | Higher |
| **Local-Pref** | Outbound | Entire AS | Higher |
| **AS-PATH** | Inbound | Global | Shorter |
| **MED** | Inbound | Between two ASs | Lower |
| **Communities** | Both | Variable | N/A |

### Pro-Tip: The "Soft Reset"
On platforms that don't re-apply policy by themselves, such as Cisco IOS, remember that whenever you change a `set` command in a route-map, you must trigger a reset to see the effects. FRR re-applies it automatically after a few seconds.

*   `clear ip bgp <neighbor> soft out` (for outbound policy)
*   `clear ip bgp <neighbor> soft in` (for inbound policy)
