```@meta
CurrentModule = CPIDataBase
```

# CPIDataBase

Este paquete provee estructuras de datos y operaciones básicas para el análisis desagregado del Índice de Precios al Consumidor (IPC). El objetivo de este paquete es proveer una herramienta de análisis y consulta de los datos desagregados a nivel de gasto básico del IPC de cualquier país para estudios relacionados con la inflación.

Vea la documentación de [`FullCPIBase`](@ref) para conocer cómo crear la estructura de datos del IPC necesaria. Los datos de un [`FullCPIBase`](@ref) pueden ser convertidos a un [`VarCPIBase`](@ref). La estructura principal de datos de este paquete es un contenedor de tipo [`CountryStructure`](@ref), el cual permite realizar cómputos de diferentes metodologías de inflación. 
