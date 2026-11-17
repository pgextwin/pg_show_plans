# pg_show_plans for Windows

Own-build packaging of upstream 2.1.8 (92ecb21f8f2307a4bc7db8f01623599e75930fc2), targeting PostgreSQL 15–18 x64. SQL extension default_version is 2.1; it is distinct from upstream 2.1.8. Requires shared_preload_libraries=pg_show_plans.

The build hook reuses the Catalog native pilot MSVC correction: PG_FUNCTION_INFO_V1 supplies the redundant function declaration. LICENSE is the exact upstream 2.1.8 PostgreSQL License, retained in each package. CI artifacts are unsigned; signing and publication use the shared owner-source route and remain separate owner operations.
