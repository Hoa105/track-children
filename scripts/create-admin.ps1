# Tạo tài khoản super admin đầu tiên cho web admin (không có trang tự đăng ký).
# Các admin sau đó được mời từ trang "Quản trị viên & vai trò".
#
#   ./scripts/create-admin.ps1 -Email lan@trackchildren.vn -FullName "Lan Nguyễn"
#
# Mật khẩu được hash bcrypt bằng pgcrypto (crypt + gen_salt('bf')), tương thích
# với passlib/bcrypt ở backend.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Email,
    [Parameter(Mandatory)] [string]$FullName,
    [securestring]$Password,
    [string]$Container = "track-children-postgres",
    [string]$Database = "track_children"
)

$ErrorActionPreference = "Stop"

if (-not $Password) {
    $Password = Read-Host "Mật khẩu (tối thiểu 10 ký tự)" -AsSecureString
}
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
if ($plain.Length -lt 10) {
    throw "Mật khẩu cần tối thiểu 10 ký tự."
}

# Truyền giá trị qua biến psql (:'name') để không phải tự escape chuỗi SQL.
$sql = @'
BEGIN;
WITH new_admin AS (
  INSERT INTO admin.admin_users (email, password_hash, full_name, password_changed_at)
  VALUES (:'email', crypt(:'password', gen_salt('bf', 12)), :'full_name', now())
  RETURNING id
)
INSERT INTO admin.admin_user_roles (admin_user_id, role_id)
SELECT new_admin.id, r.id FROM new_admin, admin.roles r WHERE r.code = 'super_admin';
COMMIT;
'@

$sql | & docker exec -i $Container psql -v ON_ERROR_STOP=1 -q -U track_children -d $Database `
    -v "email=$Email" -v "full_name=$FullName" -v "password=$plain"
if ($LASTEXITCODE -ne 0) {
    throw "Không tạo được admin (email đã tồn tại hoặc chưa chạy migration 003?)."
}
Write-Host "Đã tạo super admin $Email."
