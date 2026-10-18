# BGP 101

**Author:** Carlos M. Martinez

**Date:** April 2026

## What ?

This course provides a comprehensive introduction to the **Border Gateway Protocol (BGP)**, the "glue" that holds the Internet together. It explores how network operators exchange routing information, enforce policies, and exert control over traffic flows to maintain a stable, loop-free global network.

Unlike theoretical deep dives, this course is designed for **practical observability and hands-on engineering**. We move beyond the "how it works" to the "how to build and fix it." By using modern, containerized environments like **FRR (Free Range Routing)** and **Containerlab**, students can simulate complex, multi-AS topologies on their own machines, gaining the confidence to manage real-world infrastructure.

Key topics covered include:

- **Core Concepts:** Understanding Autonomous Systems (ASNs), the BGP Finite State Machine (FSM), and the fundamental distinction between Internal (iBGP) and External (eBGP) sessions.
- **Protocol Mechanics & Messaging:** A deep dive into BGP message types and the underlying TCP-based transport that ensures reliability.
- **Path Selection & Policy:** Mastering the BGP Best Path Selection algorithm and understanding how Path Attributes (Weight, Local Pref, MED, AS_PATH) are used to manipulate traffic flow.
- **Internal BGP (iBGP):** Navigating the complexities of internal route propagation, the split-horizon rule, and scalable architectures using Route Reflectors.
- **Route Origination & Hygiene:** Professional techniques for announcing prefixes to the world, including the "Exact Match" rule, route anchoring with Null0/blackhole routes, and safe redistribution strategies.
- **Verification & Troubleshooting:** Developing a systematic approach to debugging BGP sessions, including interpreting the BGP table, verifying advertisements, and using soft-resets to apply policy changes without disruption.

## Table of Contents

1. [Basic Concepts](01-basic-concepts.md)
2. [BGP Messages](02-bgp-messages.md)
3. [Path Attributes and Best Path Selection](03-path-attributes-bestpath-selection.md)
4. [Lab 1: Establishing Basic Connectivity](04-lab-1.md)
5. [Announcing My Routes to the World](05-announcing-my-routes.md)
6. [iBGP Mechanics and Internal Propagation](06-ibgp-mechanics.md)
7. [Lab 2: iBGP and Route Origination](07-lab-2.md)
8. [Accepting Routes from Others](08-accepting-routes-from-others.md)
9. [Traffic Engineering](09-traffic-engineering.md)
10. [Lab 3: Multi-Homing and Policy](10-lab-3.md)
11. [Lab 4: Capstone - The Regional ISP](11-lab-4.md)

## References & Further Reading

### Official Specifications
- **[RFC 4271](https://datatracker.ietf.org/doc/html/rfc4271):** A Border Gateway Protocol 4 (BGP-4).
- **[RFC 4456](https://datatracker.ietf.org/doc/html/rfc4456):** BGP Route Reflection: An Alternative to Full Mesh Internal BGP.
- **[RFC 1997](https://datatracker.ietf.org/doc/html/rfc1997):** BGP Communities Attribute.

### Tools used in this course
- **[FRR (Free Range Routing)](https://frrouting.org/):** The IP routing protocol suite for Linux and Unix platforms.
- **[Containerlab](https://containerlab.dev/):** Orchestration for container-based networking labs.

### Community Resources
- **[Hurricane Electric BGP Toolkit](https://bgp.he.net/):** Essential tool for checking global routing information and ASN details.
- **[NANOG BGP Tutorials](https://www.nanog.org/resources/tutorials/):** High-quality presentations and videos from the North American Network Operators Group.
- **[BGPStream](https://bgpstream.com/):** A free resource for monitoring BGP hijacking, leaks, and outages.
