```@meta
CurrentModule = CPIDataBase
```

# CPIDataBase

Este paquete provee estructuras de datos y operaciones básicas para el análisis desagregado del Índice de Precios al Consumidor (IPC). El objetivo de este paquete es proveer una herramienta de análisis y consulta de los datos desagregados a nivel de gasto básico del IPC de cualquier país para estudios relacionados con la inflación.


## Estructura de datos del IPC

La estructura principal de datos es un contenedor de tipo [`CountryStructure`](@ref). Supongamos que los datos del IPC de un país se encuentran disponibles en la constante `countrydata`: 

```@setup showcase-package
using CPIDataBase
using CPIDataBase.TestHelpers
countrydata = getrandomcountryst()
```

```@example showcase-package
using CPIDataBase
countrydata
```

Este contenedor posee los datos del IPC de Macronia, de las últimas dos décadas. Está dividido en dos estructuras de datos denominadas [`VarCPIBase`](@ref). Cada estructura contiene las variaciones intermensuales de los números índices de precios de los gastos básicos individuales del IPC de Macronia. A su vez, el IPC de Macronia está dividido históricamente en dos bases del IPC, cada una conlleva una  metodología diferente, con diferentes gastos básicos y ponderaciones en la canasta de consumo: 

Por ejemplo, estos son los datos históricos de Macronia en la década del 2000: 
```@example showcase-package
countrydata[1]
```

Y estos son los datos históricos de Macronia en la década del 2010: 
```@example showcase-package
countrydata[2]
```

Vea la documentación de [`FullCPIBase`](@ref) para conocer cómo crear la estructura de datos del IPC necesaria. Los datos de un [`FullCPIBase`](@ref) pueden ser convertidos a un [`VarCPIBase`](@ref). La estructura principal de datos de este paquete es un contenedor de tipo [`CountryStructure`](@ref), el cual permite realizar cómputos de diferentes metodologías de inflación. 

## Cómputo del IPC

Con la estructura `countrydata` es posible computar el Índice de Precios al Consumidor encadenado automáticamente entre las dos bases del IPC: 

```@example showcase-package
inflfn = InflationTotalCPI()
inflfn(countrydata, CPIIndex())
```

En este ejemplo, la variable `inflfn` denota una "función de inflación". Utilizando diferentes funciones de inflación podemos computar diferentes medidas de inflación con los datos desagregados del IPC. Por ejemplo, el siguiente código computa la variación interanual del IPC, ampliamente utilizada como una medida de inflación en las economías del mundo: 
```@example showcase-package
inflfn = InflationTotalCPI()
inflfn(countrydata)
```