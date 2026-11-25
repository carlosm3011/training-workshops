# DNS y DNSSEC para Operadores

**Autores:** Carlos Martinez-Cagnazzo (LACNIC), Nicolás Antoniello

**Licencia:** CC BY

## ¿Qué es?

Un curso práctico de DNSSEC orientado a operadores de redes pequeños y medianos: ISPs, IXPs, operadores de TLDs pequeños y universidades, entre otros. Cubre desde los fundamentos de firma y validación hasta la gestión de claves con KASP en BIND, el monitoreo y la resolución de problemas, arquitecturas de firmante oculto (hidden signer) y temas avanzados como NSEC3, rollover de algoritmos, CDS/CDNSKEY y configuraciones multi-firmante.

El curso asume que el lector:

- Está familiarizado con la operación de servidores Unix, en particular Linux Ubuntu.
- Conoce los conceptos más básicos de DNS. No es un curso de DNS básico.
- Conoce los conceptos de cifrado de clave pública y funciones de hash. El texto incluye breves recordatorios, pero no es un curso de criptografía.

El espíritu del curso es promover la experimentación: ninguna cantidad de lectura reemplaza ver el DNS funcionar de manera directa, con máquinas virtuales o containers.

## Módulos

0. [Introducción y temario](index.md)
1. [Introducción a DNSSEC](01-Introduccion.md)
2. [Los registros de DNSSEC](02-Registros.md)
3. [Zonas autoritativas con BIND](03-Zonas-BIND.md)
4. [Firmando una zona con BIND y KASP](04-Firmando-con-BIND-y-KASP.md)
5. [Monitoreo y troubleshooting](05-Monitoreo-Troubleshooting.md)
6. [Arquitectura con hidden signer](06-Arquitectura-Hidden-Signer.md)
7. [DNSSEC avanzado](07-DNSSEC-Avanzado.md)

## Materiales

- **Libro (PDF):** [_book/DNS-y-DNSSEC-para-Operadores.pdf](_book/DNS-y-DNSSEC-para-Operadores.pdf), también adjunto a cada release en la [página de Releases](https://github.com/carlosm3011/training-workshops/releases).
- **Presentaciones:** una por módulo, con la plantilla de LACNIC. No se versionan; se generan con:

```sh
make slides        # desde este directorio; los .pptx quedan en _slides/
```

Ver el [README del repositorio](../README.md) para instalar las dependencias y construir el libro.

## Referencias

- **[RFC 4033](https://datatracker.ietf.org/doc/html/rfc4033), [4034](https://datatracker.ietf.org/doc/html/rfc4034), [4035](https://datatracker.ietf.org/doc/html/rfc4035):** la especificación de DNSSEC.
- **[RFC 5155](https://datatracker.ietf.org/doc/html/rfc5155):** NSEC3.
- **[RFC 9276](https://datatracker.ietf.org/doc/html/rfc9276):** parámetros recomendados para NSEC3.
- **[RFC 7344](https://datatracker.ietf.org/doc/html/rfc7344):** CDS/CDNSKEY.
- **[RFC 8901](https://datatracker.ietf.org/doc/html/rfc8901):** DNSSEC multi-firmante.
- **[BIND 9 — DNSSEC Guide](https://bind9.readthedocs.io/en/latest/dnssec-guide.html)** y **[DNSViz](https://dnsviz.net/)**.
