```@meta
CurrentModule = CPIDataBase
```

# CPIDataBase

Este paquete provee estructuras de datos y operaciones básicas para el análisis del Índice de Precios al Consumidor (IPC) de Guatemala. Los datos provistos en este paquete provienen de una [recopilación del sitio web del Instituto Nacional de Estadística de Guatemala](https://www.ine.gob.gt/ine/estadisticas/bases-de-datos/indice-de-precios-al-consumidor/). El objetivo de este paquete es proveer una herramienta de análisis y consulta de los datos desagregados del IPC de Guatemala para estudios relacionados con la inflación.

La estructura principal de datos es un contenedor de tipo [`CountryStructure`](@ref). Los datos de Guatemala se encuentran disponibles en la constante `gtdata` al cargar el paquete: 

```@example showcase-package
using CPIDataBase
gtdata
```

Este contenedor posee los datos del IPC de Guatemala de las últimas dos décadas. Está dividido en dos estructuras de datos denominadas [`VarCPIBase`](@ref). Con la estructura `gtdata` es posible computar el Índice de Precios al Consumidor de Guatemala: 

```@example showcase-package
inflfn = InflationTotalCPI()
inflfn(gtdata, CPIIndex())
```

En este ejemplo, la variable `inflfn` denota una "función de inflación". Utilizando diferentes funciones de inflación podemos computar diferentes medidas de inflación con los datos desagregados del IPC. Por ejemplo, el siguiente código computa la variación interanual del IPC, ampliamente utilizada como una medida de inflación en las economías del mundo: 
```@example showcase-package
inflfn = InflationTotalCPI()
inflfn(gtdata)
```

