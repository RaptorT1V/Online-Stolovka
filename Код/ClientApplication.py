import tkinter as tk
from tkinter import messagebox
from tkinter import ttk
from ttkthemes import ThemedStyle
import psycopg2
from psycopg2 import sql

# Replace with your data
DB_NAME = "online_stolovka"
USER = "postgres"
PASSWORD = "postgres"
HOST = "localhost"
PORT = "5432"

class OnlineStolovkaApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Online Stolovka")

        # Apply the ThemedStyle
        self.style = ThemedStyle(self.root)
        self.style.set_theme("aquativo")  # You can try different themes

        # Create a connection to the database
        self.connection = self.create_connection()

        # Create a dropdown list of categories
        self.categories_label = ttk.Label(root, text="Select a category:")
        self.categories_label.pack(pady=10)

        # Adding "All" category
        self.categories = ["All"] + self.get_categories()
        self.category_var = tk.StringVar()
        self.category_dropdown = ttk.Combobox(root, textvariable=self.category_var, values=self.categories, state="readonly", width=15)
        self.category_dropdown.bind("<<ComboboxSelected>>", self.update_products)
        self.category_dropdown.pack(pady=10)

        # Create a dropdown list of products
        self.products_label = ttk.Label(root, text="Select a product:")
        self.products_label.pack(pady=10)

        self.products_var = tk.StringVar()
        self.products_dropdown = ttk.Combobox(root, textvariable=self.products_var, state="readonly", width=49)
        self.products_dropdown.pack(pady=10)

        # Create a field for entering quantity
        self.quantity_label = ttk.Label(root, text="Enter quantity:")
        self.quantity_label.pack(pady=10)

        self.quantity_var = tk.StringVar()
        self.quantity_entry = ttk.Entry(root, textvariable=self.quantity_var)
        self.quantity_entry.pack(pady=10)

        # Create a button to add to the cart
        self.add_to_cart_button = ttk.Button(root, text="Add to Cart", command=self.add_to_cart)
        self.add_to_cart_button.pack(pady=10)

        # Create a button to place an order
        self.checkout_button = ttk.Button(root, text="Place Order", command=self.checkout)
        self.checkout_button.pack(pady=10)

        # List to store selected products
        self.cart = []

    def create_connection(self):
        try:
            connection = psycopg2.connect(
                dbname=DB_NAME,
                user=USER,
                password=PASSWORD,
                host=HOST,
                port=PORT
            )
            return connection
        except psycopg2.Error as e:
            print(f"Database Connection Error: {e}")
            return None

    def get_categories(self):
        if self.connection:
            try:
                with self.connection.cursor() as cursor:
                    cursor.execute("SELECT DISTINCT category FROM products ORDER BY category")
                    categories = [category[0] for category in cursor.fetchall()]
                    return categories
            except psycopg2.Error as e:
                print(f"Query Execution Error: {e}")
        return []

    def update_products(self, event):
        category = self.category_var.get()
        if category == "All":
            products = self.get_products()
        else:
            products = self.get_products_by_category(category)

        self.products_dropdown["values"] = products
        self.products_var.set("")  # Clear the selection

    def get_products_by_category(self, category):
        if self.connection:
            try:
                with self.connection.cursor() as cursor:
                    cursor.execute("SELECT product_name FROM products WHERE category = %s ORDER BY product_name", (category,))
                    products = [product[0] for product in cursor.fetchall()]
                    return products
            except psycopg2.Error as e:
                print(f"Query Execution Error: {e}")
        return []

    def get_products(self):
        if self.connection:
            try:
                with self.connection.cursor() as cursor:
                    cursor.execute("SELECT product_name FROM products ORDER BY product_name")
                    products = [product[0] for product in cursor.fetchall()]
                    return products
            except psycopg2.Error as e:
                print(f"Query Execution Error: {e}")
        return []

    def add_to_cart(self):
        product = self.products_var.get()
        quantity = self.quantity_var.get()

        if not product or not quantity.isdigit():
            print("Input Error: Select a product and enter a valid quantity.")
            return

        # Check if the product is already in the cart
        for index, (cart_product, cart_quantity) in enumerate(self.cart):
            if cart_product == product:
                # Product is already in the cart, update the quantity
                self.cart[index] = (cart_product, cart_quantity + int(quantity))
                print(f"Updated Cart: {quantity} шт. {product} quantity updated in the cart.")
                return

        # Product is not in the cart, add a new entry
        self.cart.append((product, int(quantity)))
        print(f"Added to Cart: {quantity} шт. {product} added to the cart.")

    def checkout(self):
        if not self.cart:
            print("Empty Cart: Add products to the cart before checking out.")
            return

        try:
            with self.connection.cursor() as cursor:
                # Create an order in the 'orders' table
                cursor.execute(
                    sql.SQL("INSERT INTO orders (customer_id, total_price, short_id, status) VALUES (1, %s, %s, 'Completed') RETURNING order_id"),
                    (self.calculate_total_price(), self.generate_short_id())
                )
                order_id = cursor.fetchone()[0]

                # Add order details to the 'order_details' table
                for product, quantity in self.cart:
                    # Retrieve product_id and valid_unit_price
                    cursor.execute("SELECT product_id, valid_unit_price FROM products WHERE product_name = %s", (product,))
                    result = cursor.fetchone()
                    product_id, valid_unit_price = result[0], result[1]

                    # Insert data into 'order_details'
                    cursor.execute(
                        sql.SQL("INSERT INTO order_details (order_id, product_id, quantity, price) VALUES (%s, %s, %s, %s)"),
                        (order_id, product_id, quantity, valid_unit_price * quantity)
                    )

                self.connection.commit()

                # Display information about the placed order in a pop-up window
                order_info = self.get_order_info(order_id)
                messagebox.showinfo("Order Placed", order_info)

                print("Order Placed: Order placed successfully.")
                self.cart = []  # Clear the cart after placing the order
        except psycopg2.Error as e:
            print(f"Query Execution Error: {e}")

    def get_order_info(self, order_id):
        # Retrieve order information for the pop-up window
        if self.connection:
            try:
                with self.connection.cursor() as cursor:
                    cursor.execute("SELECT product_name, quantity, price FROM order_details JOIN products USING (product_id) WHERE order_id = %s ORDER BY category", (order_id,))
                    order_details = cursor.fetchall()
                    total_price = sum(detail[2] for detail in order_details)

                    order_info = f"Order ID: {order_id}\n\n"
                    for detail in order_details:
                        order_info += f"{detail[0]} - {detail[1]} шт. - {detail[2]}₽\n"
                    order_info += f"\nTotal Price: {total_price}₽"

                    return order_info
            except psycopg2.Error as e:
                print(f"Query Execution Error: {e}")
        return "Error: Unable to retrieve order information"

    def calculate_total_price(self):
        total_price = sum(self.get_product_price(product) * quantity for product, quantity in self.cart)
        return total_price

    def get_product_price(self, product):
        if self.connection:
            try:
                with self.connection.cursor() as cursor:
                    cursor.execute("SELECT valid_unit_price FROM products WHERE product_name = %s", (product,))
                    price = cursor.fetchone()[0]
                    return price
            except psycopg2.Error as e:
                print(f"Query Execution Error: {e}")
        return 0  # Default to 0 if there's an error

    def generate_short_id(self):
        # Code to generate a short ID, you can customize this based on your requirements
        # For simplicity, let's just return a random 4-digit number as a string
        import random
        return str(random.randint(1000, 9999))

if __name__ == "__main__":
    root = tk.Tk()
    app = OnlineStolovkaApp(root)
    root.mainloop()