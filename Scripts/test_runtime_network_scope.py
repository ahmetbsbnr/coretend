import os
import socket
import unittest

from Scripts.runtime_network_scope import internet_socket_processes


class RuntimeNetworkScopeTests(unittest.TestCase):
    def test_reports_process_with_open_internet_socket(self):
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            self.assertEqual(internet_socket_processes(os.getpid()), {os.getpid()})
        finally:
            listener.close()


if __name__ == "__main__":
    unittest.main()
