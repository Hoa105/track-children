# Database

SQL nguồn backend nằm trong [`backend/migrations`](../../backend/migrations/), SQL nguồn AI nằm trong [`ai-service/migrations`](../../ai-service/migrations/). Runner: [`scripts/migrate.ps1`](../../scripts/migrate.ps1).

Auth dùng một migration đã gộp: `009_auth_database_simplification.sql`, đưa thẳng về 5 bảng đích (reset dữ liệu auth; chặn nếu nghiệp vụ còn tham chiếu tài khoản). Không còn file 010. Xem [kế hoạch triển khai](auth-migration-plan.md), [danh mục dữ liệu](../../DATA-DICTIONARY.md) và [ma trận quan hệ](../../RELATIONSHIP-MATRIX.md).
