import os
import sys
import time
import shutil
import subprocess

# --- КОНСТАНТЫ ---
APP_NAME = "MFT (Manager Files Terminal)"
INST_VERSION = "v2"
DEFAULT_PATH = "/usr/local/bin/mft"

def clear_screen():
    os.system('clear' if os.name == 'posix' else 'cls')

def show_logs(logs):
    print("\n--- ЛОГ ОТЛАДКИ ---")
    for line in logs:
        print(line)
    print("-------------------\n")

def show_final_step(success, logs):
    print(f"\n========================================")
    status = "УСПЕШНО" if success else "С ОШИБКАМИ"
    print(f"   ПРОЦЕСС ЗАВЕРШЕН {status}!")
    print(f"========================================\n")

    if input("Показать лог отладки? (y/n): ").lower() == 'y':
        show_logs(logs)

    print("ЧТО ДАЛЬШЕ?")
    print("1. Выйти")
    print("2. Начать заново (В начало)")
    
    if input("\nВаш выбор: ") == '2':
        main()
    else:
        sys.exit()

def run_installation(target_path, version="v2"):
    logs = []
    clear_screen()
    target_dir = os.path.dirname(target_path)
    
    print(f"--- Установка MFT {version} ---")
    
    make_alias = input("Создать alias в .bashrc? (y/n): ").lower()
    if input(f"Начать установку {version} в {target_path}? (y/n): ").lower() != 'y':
        return

    try:
        # Исходный файл
        source_file = os.path.join("mft_binaries", version, "mft")
        logs.append(f"[DEBUG] Проверка источника: {source_file}")
        if not os.path.exists(source_file):
            raise FileNotFoundError(f"Файл 'mft' не найден в {source_file}")

        # Анимация установки
        for i in range(11):
            time.sleep(0.1)
            sys.stdout.write(f"\rУстановка: [{'#'*i}{'.'*(10-i)}] {i*10}%")
            sys.stdout.flush()
        print()

        # Проверка sudo/root
        if shutil.which("sudo") is None and os.geteuid() != 0:
            raise PermissionError("Требуются права root или sudo для установки")

        # Создание папки
        subprocess.run(['sudo', 'mkdir', '-p', target_dir], check=True)
        logs.append(f"[DEBUG] Папка {target_dir} готова")

        # Копирование и установка прав
        subprocess.run(['sudo', 'cp', source_file, target_path], check=True)
        logs.append(f"[DEBUG] Файл скопирован в {target_path}")
        subprocess.run(['sudo', 'chmod', '+x', target_path], check=True)
        logs.append("[DEBUG] Права +x установлены")

        # Alias
        if make_alias == 'y':
            bashrc = os.path.expanduser("~/.bashrc")
            with open(bashrc, "r+") as f:
                lines = f.read()
                if f"alias mft=" not in lines:
                    f.write(f"\nalias mft='sudo {target_path}'\n")
                    logs.append("[DEBUG] Alias добавлен")
                else:
                    logs.append("[DEBUG] Alias уже существует")

        show_final_step(True, logs)

    except Exception as e:
        logs.append(f"[ERROR] {str(e)}")
        show_final_step(False, logs)

def recovery_menu(target_path):
    clear_screen()
    print("--- МЕНЮ ВОССТАНОВЛЕНИЯ ---")
    print("1. Удалить программу")
    print("2. Переустановить последнюю версию")
    print("3. Выбрать другую версию (v1, v2...)")
    print("4. Назад")
    
    choice = input("\nВыбор: ")
    if choice == '1':
        path = input(f"Путь для удаления ({target_path}): ") or target_path
        if os.path.exists(path):
            try:
                if os.path.isdir(path):
                    subprocess.run(['sudo', 'rm', '-rf', path], check=True)
                else:
                    subprocess.run(['sudo', 'rm', path], check=True)
                print(f"Файл/папка {path} удален(а).")
            except subprocess.CalledProcessError as e:
                print(f"[ERROR] Не удалось удалить: {e}")
        else:
            print("Файл не найден.")
        input("Нажмите Enter...")
        main()
    elif choice == '2':
        run_installation(target_path, "v2")
    elif choice == '3':
        try:
            base_dir = "mft_binaries"
            if not os.path.exists(base_dir):
                raise FileNotFoundError(f"Папка {base_dir} не найдена!")

            versions = [d for d in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, d))]
            versions.sort()
            
            if not versions:
                print("\n[ОШИБКА] В папке mft_binaries нет подпапок с версиями!")
                input("Нажмите Enter...")
                return recovery_menu(target_path)

            print("\nДоступные версии в системе:")
            for i, v in enumerate(versions, 1):
                print(f"{i}. {v}")
            
            v_idx = int(input("\nВыберите номер версии: ")) - 1
            selected_version = versions[v_idx]
            
            print(f"[OK] Выбрана {selected_version}. Переходим к установке...")
            run_installation(target_path, version=selected_version)

        except Exception as e:
            print(f"[ERROR] Не удалось прочитать папки версий: {e}")
            input("\nНажмите Enter...")
            main()

def main():
    clear_screen()
    print(f"========================================")
    print(f"   {APP_NAME} Installer {INST_VERSION}")
    print(f"   Автор: ZuteroG | zuterog@gmail.com")
    print(f"========================================\n")

    path = input(f"Куда установить? (Default: {DEFAULT_PATH}): ") or DEFAULT_PATH

    # Лицензия
    print("\nЛицензионое Соглашение")
    print("1. Автор не несет ответственности за ваши данные")
    print("2. Вы соглашаетесь с Лицензией MIT")
    print("3. Автор не несет ответственности за модификации и форки")
    print("4. Полный отказ претензий к автору")
    print("5. Для связи с автором: zuterog@gmail.com")
    if input("Согласны? (y/n): ").lower() != 'y': sys.exit()

    print("\n1. Установка\n2. Восстановление/Удаление")
    if input("Вариант: ") == '2':
        recovery_menu(path)
    else:
        run_installation(path)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nПроцесс прерван.")