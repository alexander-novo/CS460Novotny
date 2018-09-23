#pragma once

template <typename NodeVal>
class BinaryTree {
	public:
		// Constructors
		BinaryTree();
		BinaryTree(const BinaryTree<NodeVal>& other);

		// Operators
		BinaryTree<NodeVal>& operator = (const BinaryTree<NodeVal>& other);

		// Member functions
		bool insert(const NodeVal& val);
		BinaryTree<NodeVal>* copy() const;

		NodeVal* find(const NodeVal& key);
		// Destructors
		~BinaryTree();

	private:
		struct Node {
			Node() {}
			Node(NodeVal val, Node* left_ptr, Node* right_ptr, bool is_red):
				data(val),
				left(left_ptr),
				right(right_ptr),
				red(is_red) {}
			NodeVal data;
			Node* left;
			Node* right;
			bool red;
		};

		Node* root;
};

/**
 * Constructor.
 * @param None.
 * @return None.
 */
template<typename T>
BinaryTree<T>::BinaryTree() {
	root = nullptr;
}

/**
 * Copy constructor.
 * @param {const BinaryTree&} other - The BT to copy into this
 * @return None
 */
template<typename T>
BinaryTree<T>::BinaryTree(const BinaryTree<T>& other) {
	(*this) = other;
}

/**
 * Assignment operator.
 * @param {const BinaryTree&} other - The BT to assign to this
 * @return {BinaryTree&} - To allow A = B = C;
 */
template<typename T>
BinaryTree<T>& BinaryTree<T>::operator = (const BinaryTree<T>& other) {

}

/**
 * Insert a value into the tree.
 * @param {const T&} val - The value to insert into the tree.
 * @return {bool} - Whether or not it ws successfully inserted.
 */
template<typename T>
bool BinaryTree<T>::insert(const T& val) {

}

/**
 * Create a new binary tree and return a pointer to that new tree.
 * @param None
 * @return {BinaryTree<T>*} - The pointer to the new tree.
 */
template<typename T>
BinaryTree<T>* BinaryTree<T>::copy() const{
	if (root == nullptr) {
		return nullptr;
	}
	return nullptr; // For now...
}

/**
 * Find and return a pointer to the value pointed to by the key.
 * @param {const NodeVal&} key - The key to search for.
 * @return {NodeVal*} - The pointer to the node found.
 */
template<typename T>
T* BinaryTree<T>::find(const T& key) {
	if (root == nullptr) {
		return nullptr;
	}
	Node* conductor = root;
	while (conductor != nullptr) {
		if (key == conductor->data) {
			return &conductor->data;
		}
		if (key < conductor->data) {
			conductor = conductor->left;
		} else if (key > conductor->data) {
			conductor = conductor->right;
		}
	}
	return nullptr;
}

/**
 * Carefully delete all of the nodes.
 * @param None
 * @return None
 */
template<typename T>
BinaryTree<T>::~BinaryTree() {

}
